/*
 * picoruby-gem-installer - Main Entry Point
 * 
 * このファイルはmrubyバイトコードを読み込んで実行します。
 * ビルド時に mrblib/downloader.rb がバイトコードに変換され、
 * app_bytecode.c として埋め込まれます。
 */

#include <stdio.h>
#include <stdlib.h>

#include <mruby.h>
#include <mruby/irep.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <mruby/class.h>

/* mrbc -B で生成されるバイトコード */
#include "app_bytecode.c"

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
