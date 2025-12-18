/*
 * picoruby-gem-installer - Main Entry Point
 *
 * このファイルはmrubyバイトコードを読み込んで実行します。
 * ビルド時に mrblib/downloader.rb がバイトコードに変換され、
 * app_bytecode.c として埋め込まれます。
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <mruby/compile.h>
#include <mruby/dump.h>
#include <mruby/proc.h>
#include <mruby/class.h>

/* mrbc -B で生成されるバイトコード */
#include "app_bytecode.c"

/*
 * Mrbc.compile(source_path, output_path) -> true/false
 *
 * Ruby ソースファイルを .mrb バイトコードにコンパイルする
 */
static mrb_value
mrb_mrbc_compile(mrb_state *mrb, mrb_value self)
{
    const char *source_path;
    const char *output_path;
    FILE *source_file;
    FILE *output_file;
    struct mrb_parser_state *parser;
    struct RProc *proc;
    int result;

    mrb_get_args(mrb, "zz", &source_path, &output_path);

    /* ソースファイルを開く */
    source_file = fopen(source_path, "r");
    if (source_file == NULL) {
        mrb_raisef(mrb, E_RUNTIME_ERROR, "Cannot open source file: %s", source_path);
        return mrb_false_value();
    }

    /* パースする */
    parser = mrb_parse_file(mrb, source_file, NULL);
    fclose(source_file);

    if (parser == NULL) {
        mrb_raise(mrb, E_RUNTIME_ERROR, "Failed to create parser");
        return mrb_false_value();
    }

    if (parser->nerr > 0) {
        /* パースエラーがある場合 */
        if (parser->error_buffer[0].message) {
            mrb_raisef(mrb, E_SYNTAX_ERROR, "%s:%d: %s",
                source_path,
                parser->error_buffer[0].lineno,
                parser->error_buffer[0].message);
        } else {
            mrb_raisef(mrb, E_SYNTAX_ERROR, "Parse error in %s", source_path);
        }
        mrb_parser_free(parser);
        return mrb_false_value();
    }

    /* コード生成 */
    proc = mrb_generate_code(mrb, parser);
    mrb_parser_free(parser);

    if (proc == NULL) {
        mrb_raisef(mrb, E_RUNTIME_ERROR, "Failed to generate code for %s", source_path);
        return mrb_false_value();
    }

    /* 出力ファイルを開く */
    output_file = fopen(output_path, "wb");
    if (output_file == NULL) {
        mrb_raisef(mrb, E_RUNTIME_ERROR, "Cannot open output file: %s", output_path);
        return mrb_false_value();
    }

    /* バイトコードをダンプ */
    result = mrb_dump_irep_binary(mrb, proc->body.irep, 0, output_file);
    fclose(output_file);

    if (result != MRB_DUMP_OK) {
        mrb_raisef(mrb, E_RUNTIME_ERROR, "Failed to dump bytecode to %s", output_path);
        return mrb_false_value();
    }

    return mrb_true_value();
}

/*
 * Mrbc モジュールを初期化
 */
static void
mrb_init_mrbc_module(mrb_state *mrb)
{
    struct RClass *mrbc_module;

    mrbc_module = mrb_define_module(mrb, "Mrbc");
    mrb_define_module_function(mrb, mrbc_module, "compile", mrb_mrbc_compile, MRB_ARGS_REQ(2));
}

int main(int argc, char *argv[])
{
    mrb_state *mrb;
    mrb_value ARGV;
    int i;
    int return_code = 0;

    /* mruby VMを初期化 */
    mrb = mrb_open();
    if (mrb == NULL) {
        fprintf(stderr, "Error: Failed to initialize mruby VM\n");
        return 1;
    }

    /* Mrbc モジュールを初期化 */
    mrb_init_mrbc_module(mrb);

    /* コマンドライン引数をARGVとして設定 */
    ARGV = mrb_ary_new_capa(mrb, argc - 1);
    for (i = 1; i < argc; i++) {
        mrb_ary_push(mrb, ARGV, mrb_str_new_cstr(mrb, argv[i]));
    }
    mrb_define_global_const(mrb, "ARGV", ARGV);

    /* $PROGRAM_NAME を設定 */
    mrb_gv_set(mrb, mrb_intern_lit(mrb, "$PROGRAM_NAME"),
               mrb_str_new_cstr(mrb, argv[0]));

    /* バイトコードを実行 */
    mrb_load_irep(mrb, app_bytecode);

    /* 例外チェック */
    if (mrb->exc) {
        mrb_value exc = mrb_obj_value(mrb->exc);
        struct RClass *system_exit = mrb_class_get(mrb, "SystemExit");

        if (mrb_obj_is_kind_of(mrb, exc, system_exit)) {
            /* SystemExit の status を取得 */
            mrb_value status = mrb_iv_get(mrb, exc, mrb_intern_lit(mrb, "status"));
            return_code = mrb_nil_p(status) ? 0 : mrb_fixnum(status);
        } else {
            mrb_print_error(mrb);
            return_code = 1;
        }
    }

    /* クリーンアップ */
    mrb_close(mrb);

    return return_code;
}
