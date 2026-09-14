#define _DEFAULT_SOURCE
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <xcb/xcb.h>
#include "ipc.h"

static xcb_connection_t *c;
static xcb_window_t windows[5];
static const char *bin;
static void settle(void) { xcb_flush(c); usleep(100000); }

static int run(const char *const *args, char *output, size_t capacity) {
 int fds[2]; assert(pipe(fds)==0);
 pid_t pid=fork(); assert(pid>=0);
 if(!pid) {
  close(fds[0]);assert(dup2(fds[1],STDOUT_FILENO)>=0);close(fds[1]);
  char *argv[20];int n=0;argv[n++]=(char *)bin;
  while(*args) {assert(n<19);argv[n++]=(char *)*args++;}
  argv[n]=NULL;execv(bin,argv);_exit(127);
 }
 close(fds[1]);size_t length=0;ssize_t bytes;
 while((bytes=read(fds[0],output+length,capacity-1-length))>0) {
  length+=bytes;assert(length<capacity-1);
 }
 assert(bytes==0);output[length]=0;close(fds[0]);
 int status;assert(waitpid(pid,&status,0)==pid);settle();
 return WIFEXITED(status)?WEXITSTATUS(status):255;
}
static void check(const char *const *args, unsigned expected, bool valid) {
 char output[4096];int status=run(args,output,sizeof output);
 if(!valid) {assert(status!=0);assert(!output[0]);return;}
 assert(status==0);unsigned found=0;char *save=NULL;
 for(char *line=strtok_r(output,"\n",&save);line;line=strtok_r(NULL,"\n",&save)) {
  char *end;unsigned long id=strtoul(line,&end,16);assert(!*end);
  int i;for(i=0;i<5;i++)if(windows[i]==id)break;
  assert(i<5);assert(!(found&(1u<<i)));found|=1u<<i;
 }
 if(found!=expected)fprintf(stderr,"query mismatch: expected %x got %x\n",expected,found);
 assert(found==expected);
}
#define QUERY(expected, ...) check((const char *const[]){"window","ids",__VA_ARGS__,NULL},expected,true)
#define INVALID(...) check((const char *const[]){"window","ids",__VA_ARGS__,NULL},0,false)
static xcb_atom_t atom(const char *name) {
 xcb_intern_atom_reply_t *r=xcb_intern_atom_reply(c,
  xcb_intern_atom(c,0,strlen(name),name),NULL);
 assert(r);xcb_atom_t value=r->atom;free(r);return value;
}
static void invalid_payload(xcb_window_t root) {
 xcb_window_t reply=xcb_generate_id(c);
 xcb_create_window(c,0,reply,root,0,0,1,1,0,XCB_WINDOW_CLASS_INPUT_ONLY,0,0,NULL);
 xcb_atom_t request=atom(ATOM_REQUEST),response=atom(ATOM_RESPONSE);
 for(int i=0;i<4;i++) {
  uint32_t data[]={i==0?0:2,2};
  xcb_change_property(c,XCB_PROP_MODE_REPLACE,reply,request,
   i==1?XCB_ATOM_STRING:XCB_ATOM_CARDINAL,i==2?8:32,i==3?2:1,data);
  xcb_client_message_event_t event={0};event.response_type=XCB_CLIENT_MESSAGE;
  event.format=32;event.type=atom(ATOM_COMMAND);event.data.data32[0]=IPCWindowIds;
  event.data.data32[1]=reply;
  xcb_send_event(c,0,root,XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT,(char *)&event);settle();
  xcb_get_property_reply_t *r=xcb_get_property_reply(c,
   xcb_get_property(c,1,reply,response,XCB_ATOM_STRING,0,100),NULL);
  assert(r);assert(xcb_get_property_value_length(r)>=6);
  assert(!memcmp(xcb_get_property_value(r),"ERROR ",6));free(r);
 }
 xcb_destroy_window(c,reply);settle();
}
int main(int argc,char **argv) {
 assert(argc==2);bin=argv[1];c=xcb_connect(NULL,NULL);assert(!xcb_connection_has_error(c));
 xcb_screen_t *screen=xcb_setup_roots_iterator(xcb_get_setup(c)).data;
 invalid_payload(screen->root);
 for(int i=0;i<5;i++) {
  windows[i]=xcb_generate_id(c);
  xcb_create_window(c,0,windows[i],screen->root,50,50,200,200,0,
   XCB_WINDOW_CLASS_INPUT_OUTPUT,screen->root_visual,0,NULL);
  const char firefox[]="firefox\0Firefox";const char other[]="other\0Other";
  const char *klass=i<3?firefox:other;size_t length=i<3?sizeof firefox:sizeof other;
  xcb_change_property(c,XCB_PROP_MODE_REPLACE,windows[i],XCB_ATOM_WM_CLASS,XCB_ATOM_STRING,8,length,klass);
  const char *title=i<3?"foo title":"bar title";
  xcb_change_property(c,XCB_PROP_MODE_REPLACE,windows[i],XCB_ATOM_WM_NAME,XCB_ATOM_STRING,8,strlen(title),title);
  xcb_map_window(c,windows[i]);settle();
  char xid[16],output[1024];snprintf(xid,sizeof xid,"0x%08x",windows[i]);
  if(i<4)assert(!run((const char *const[]){"group","add",i==0?"1":"2",xid,NULL},output,sizeof output));
  if(i==4)assert(!run((const char *const[]){"group","remove",xid,NULL},output,sizeof output));
  if(i==2)assert(!run((const char *const[]){"window","hide",xid,NULL},output,sizeof output));
 }
 QUERY(0x1b,NULL);QUERY(0x1f,"--all");
 QUERY(0x03,"Firefox");QUERY(0x07,"--all","Firefox");QUERY(0x07,"Firefox","--all");
 QUERY(0x03,"--name","foo");QUERY(0x07,"--all","--name","foo");
 QUERY(0x01,"--group","1");QUERY(0x0a,"--group","2");
 QUERY(0x0e,"--all","--group","2");QUERY(0x0e,"--group","2","--all");
 QUERY(0x02,"Firefox","--group","2");QUERY(0x02,"--group","2","Firefox");
 QUERY(0x06,"Firefox","--group","2","--all");
 QUERY(0x02,"--name","foo","--group","2");QUERY(0x02,"--group","2","--name","foo");
 QUERY(0x06,"--all","--name","foo","--group","2");
 QUERY(0x06,"--all","--group","2","--name","foo");
 QUERY(0x06,"--group","2","--all","--name","foo");
 QUERY(0,"--group","2","--name","absent");
 char count_output[128];
 assert(!run((const char *const[]){"group","count",NULL},count_output,sizeof count_output));
 unsigned group_count=(unsigned)strtoul(count_output,NULL,10);assert(group_count>2);
 char boundary[32];snprintf(boundary,sizeof boundary,"%u",group_count);
 INVALID("--group",boundary);
 snprintf(boundary,sizeof boundary,"%u",group_count-1);
 QUERY(group_count-1==2?0x0a:0,"--group",boundary);
 INVALID("--group","0");INVALID("--group","4294967295");INVALID("--group","nonnumeric");
 INVALID("--group","current");INVALID("--group");INVALID("--group","2","--group","2");
 INVALID("--group","-1");INVALID("--group","4294967296");
 INVALID("Firefox","--name","foo","--group","2");INVALID("--name","[");
 /* A group transition changes visibility, not membership or --all scope. */
 char output[1024];assert(!run((const char *const[]){"group","deactivate","2",NULL},output,sizeof output));
 QUERY(0,"--group","2");QUERY(0x0e,"--all","--group","2");QUERY(0x11,NULL);
 QUERY(0x06,"--all","--name","foo","--group","2");
 assert(!run((const char *const[]){"group","activate","2",NULL},output,sizeof output));
 QUERY(0x0e,"--group","2");QUERY(0x1f,NULL);
 puts("PASS: ids visibility, public groups, all/class/name combinations, option ordering, validation, group hide/restore");
 xcb_disconnect(c);return 0;
}
