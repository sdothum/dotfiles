#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/xcb.h>
#include <xcb/xproto.h>

typedef struct { uint32_t output; int16_t x,y; uint16_t width,height; uint8_t active; } MockMonitor;
static MockMonitor monitors[16];
static int monitor_count, snapshot_failure, init_calls, select_calls;
static int configure_calls, property_calls, flush_calls, focus_calls;
static uint32_t configure_windows[32], configure_values[32][4];
static uint16_t configure_masks[32];
static int request_order[128], request_order_count;
void randr_mock_set(const MockMonitor *values,int count){monitor_count=count;if(count>16)abort();if(count)memcpy(monitors,values,(size_t)count*sizeof(*values));}
void randr_mock_fail_snapshot(int value){snapshot_failure=value;}
int randr_mock_init_calls(void){return init_calls;}
int randr_mock_select_calls(void){return select_calls;}
int randr_mock_configure_calls(void){return configure_calls;}
int randr_mock_property_calls(void){return property_calls;}
int randr_mock_flush_calls(void){return flush_calls;}
int randr_mock_focus_calls(void){return focus_calls;}
void randr_mock_reset_requests(void){configure_calls=property_calls=flush_calls=focus_calls=0;request_order_count=0;memset(configure_windows,0,sizeof(configure_windows));memset(configure_values,0,sizeof(configure_values));memset(configure_masks,0,sizeof(configure_masks));}
uint32_t randr_mock_configure_window(int index){return configure_windows[index];}
uint16_t randr_mock_configure_mask(int index){return configure_masks[index];}
uint32_t randr_mock_configure_value(int index,int field){return configure_values[index][field];}
int randr_mock_request_order(int index){return request_order[index];}
int cirrus_randr_initialize(xcb_connection_t*c){(void)c;init_calls++;return 80;}
void cirrus_randr_select(xcb_connection_t*c,xcb_window_t root){(void)c;(void)root;select_calls++;}
int cirrus_randr_snapshot(xcb_connection_t*c,xcb_window_t root,MockMonitor **out){(void)c;(void)root;*out=NULL;if(snapshot_failure)return -1;if(!monitor_count)return 0;*out=malloc((size_t)monitor_count*sizeof(**out));if(!*out)return -1;memcpy(*out,monitors,(size_t)monitor_count*sizeof(**out));return monitor_count;}
void cirrus_randr_free(MockMonitor*p){free(p);}
int xcb_connection_has_error(xcb_connection_t*c){(void)c;return 0;}
xcb_void_cookie_t xcb_configure_window_checked(xcb_connection_t*c,xcb_window_t w,uint16_t m,const void*v){(void)c;int i=configure_calls++;if(i<32){configure_windows[i]=w;configure_masks[i]=m;if(v)memcpy(configure_values[i],v,sizeof(configure_values[i]));}if(request_order_count<128)request_order[request_order_count++]=1;return(xcb_void_cookie_t){1};}
xcb_void_cookie_t xcb_change_property_checked(xcb_connection_t*c,uint8_t mode,xcb_window_t w,xcb_atom_t p,xcb_atom_t t,uint8_t f,uint32_t n,const void*v){(void)c;(void)mode;(void)w;(void)p;(void)t;(void)f;(void)n;(void)v;property_calls++;if(request_order_count<128)request_order[request_order_count++]=2;return(xcb_void_cookie_t){1};}
xcb_generic_error_t *xcb_request_check(xcb_connection_t*c,xcb_void_cookie_t k){(void)c;(void)k;return NULL;}
int xcb_flush(xcb_connection_t*c){(void)c;flush_calls++;if(request_order_count<128)request_order[request_order_count++]=3;return 1;}
xcb_void_cookie_t xcb_set_input_focus_checked(xcb_connection_t*c,uint8_t revert,xcb_window_t w,uint32_t time){(void)c;(void)revert;(void)w;(void)time;focus_calls++;return(xcb_void_cookie_t){1};}
