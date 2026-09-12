#define _DEFAULT_SOURCE
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <xcb/xcb.h>
#include <xcb/xcb_ewmh.h>
#include "ipc.h"

static xcb_connection_t *c;
static xcb_screen_t *s;
static xcb_ewmh_connection_t e;
static xcb_window_t w[4], frames[4];
static int layers[4];
static xcb_window_t panels[3];
static int panel_layers[3] = {1, 1, 1};
static const char *bin;
static void settle(void) { xcb_flush(c); usleep(100000); }
static int command(const char *verb, const char *arg, xcb_window_t id) {
 char xid[16]; snprintf(xid, sizeof xid, "0x%08x", id);
 pid_t pid = fork(); assert(pid >= 0);
 if (!pid) {
  if (arg && id == XCB_NONE) execl(bin, bin, "window", verb, arg, (char *)NULL);
  else if (arg) execl(bin, bin, "window", verb, arg, xid, (char *)NULL);
  else execl(bin, bin, "window", verb, xid, (char *)NULL);
  _exit(127);
 }
 int status; assert(waitpid(pid, &status, 0) == pid);
 settle(); return WIFEXITED(status) ? WEXITSTATUS(status) : 255;
}
static void group_command(const char *verb, xcb_window_t id) {
 char xid[16]; snprintf(xid, sizeof xid, "0x%08x", id);
 pid_t pid=fork(); assert(pid>=0);
 if(!pid) {
  if(id) execl(bin,bin,"group",verb,"2",xid,(char*)NULL);
  else execl(bin,bin,"group",verb,"2",(char*)NULL);
  _exit(127);
 }
 int status; assert(waitpid(pid,&status,0)==pid);assert(WIFEXITED(status)&&WEXITSTATUS(status)==0);settle();
}
static void raise_many(void) {
 char ids[4][16];for(int i=0;i<4;i++)snprintf(ids[i],sizeof ids[i],"0x%08x",w[i]);
 pid_t pid=fork();assert(pid>=0);
 if(!pid) {execl(bin,bin,"window","raise-many",ids[2],ids[1],ids[3],ids[0],(char*)NULL);_exit(127);}
 int status;assert(waitpid(pid,&status,0)==pid);assert(WIFEXITED(status)&&WEXITSTATUS(status)==0);settle();
}
static xcb_window_t focused(void) {
 xcb_get_input_focus_reply_t *r = xcb_get_input_focus_reply(c, xcb_get_input_focus(c), NULL);
 assert(r); xcb_window_t id = r->focus; free(r); return id;
}
static void invariant(void) {
 xcb_query_tree_reply_t *r = xcb_query_tree_reply(c, xcb_query_tree(c, s->root), NULL);
 assert(r); xcb_window_t *ids = xcb_query_tree_children(r); int last = -1, found = 0;
 for (int i=0; i<xcb_query_tree_children_length(r); i++) {
  int tier = -1;
  for (int j=0; j<4; j++) if (ids[i] == w[j] || ids[i] == frames[j]) {
   tier=layers[j]; found++;
  }
  for (int j=0; j<3; j++) if (panels[j] && ids[i] == panels[j]) tier=panel_layers[j];
  if (tier >= 0) { assert(tier >= last); last=tier; }
 }
 assert(found == 8); free(r);
}
static int position(xcb_window_t id) {
 xcb_query_tree_reply_t *r = xcb_query_tree_reply(c, xcb_query_tree(c,s->root),NULL);
 assert(r); xcb_window_t *ids=xcb_query_tree_children(r); int pos=-1;
 for(int i=0;i<xcb_query_tree_children_length(r);i++) if(ids[i]==id) pos=i;
 free(r); assert(pos>=0); return pos;
}
static void layer(int i, int value) {
 const char *names[]={"normal","above","overlay"}; xcb_window_t focus=focused();
 assert(command("layer", names[value], w[i])==0); layers[i]=value;
 assert(focused()==focus); invariant();
}
static bool above(int i) {
 xcb_ewmh_get_atoms_reply_t r; bool found=false;
 assert(xcb_ewmh_get_wm_state_reply(&e,xcb_ewmh_get_wm_state(&e,w[i]),&r,NULL));
 for(unsigned j=0;j<r.atoms_len;j++) if(r.atoms[j]==e._NET_WM_STATE_ABOVE) found=true;
 xcb_ewmh_get_atoms_reply_wipe(&r); return found;
}
static void ewmh(int i, int action) {
 xcb_window_t focus=focused();
 xcb_ewmh_request_change_wm_state(&e,0,w[i],action,e._NET_WM_STATE_ABOVE,XCB_NONE,XCB_EWMH_CLIENT_SOURCE_TYPE_OTHER);
 settle(); assert(focused()==focus);
}
static void invalid_ipc(void) {
 xcb_intern_atom_reply_t *a=xcb_intern_atom_reply(c,xcb_intern_atom(c,0,strlen(ATOM_COMMAND),ATOM_COMMAND),NULL);
 xcb_intern_atom_reply_t *b=xcb_intern_atom_reply(c,xcb_intern_atom(c,0,strlen(ATOM_RESPONSE),ATOM_RESPONSE),NULL);
 assert(a && b); xcb_window_t reply=xcb_generate_id(c);
 xcb_create_window(c,0,reply,s->root,0,0,1,1,0,XCB_WINDOW_CLASS_INPUT_ONLY,0,0,NULL);
 xcb_client_message_event_t ev={0};ev.response_type=XCB_CLIENT_MESSAGE;ev.format=32;ev.type=a->atom;
 ev.data.data32[0]=IPCActionWindowLayer;ev.data.data32[1]=reply;ev.data.data32[2]=1;ev.data.data32[3]=w[0];ev.data.data32[4]=99;
 xcb_send_event(c,0,s->root,XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT,(char*)&ev);settle();
 xcb_get_property_reply_t *r=xcb_get_property_reply(c,xcb_get_property(c,0,reply,b->atom,XCB_ATOM_STRING,0,100),NULL);
 assert(r && xcb_get_property_value_length(r)>=6 && !memcmp(xcb_get_property_value(r),"ERROR ",6));
 free(r);free(a);free(b);xcb_destroy_window(c,reply);
}
int main(int argc,char **argv) {
 assert(argc==2);bin=argv[1];c=xcb_connect(NULL,NULL);assert(!xcb_connection_has_error(c));
 s=xcb_setup_roots_iterator(xcb_get_setup(c)).data;
 assert(xcb_ewmh_init_atoms_replies(&e,xcb_ewmh_init_atoms(c,&e),NULL));
 for(int i=0;i<4;i++) {
  w[i]=xcb_generate_id(c);xcb_create_window(c,0,w[i],s->root,50,50,200,200,0,XCB_WINDOW_CLASS_INPUT_OUTPUT,s->root_visual,0,NULL);
  if(i==3) {xcb_atom_t a=e._NET_WM_STATE_ABOVE;xcb_ewmh_set_wm_state(&e,w[i],1,&a);layers[i]=1;}
  xcb_map_window(c,w[i]);settle();
  xcb_query_tree_reply_t *tree=xcb_query_tree_reply(c,xcb_query_tree(c,s->root),NULL);assert(tree);
  xcb_window_t *children=xcb_query_tree_children(tree);
  for(int j=0;j<xcb_query_tree_children_length(tree);j++) {
   xcb_get_window_attributes_reply_t *a=xcb_get_window_attributes_reply(c,xcb_get_window_attributes(c,children[j]),NULL);assert(a);
   if(a->override_redirect) {
    bool known=false;for(int k=0;k<i;k++)if(frames[k]==children[j])known=true;
    if(!known)frames[i]=children[j];
   }
   free(a);
  }
  free(tree);assert(frames[i]);
 }
 /* A Conky-shaped panel (DOCK+ABOVE) and an override-redirect DOCK
  * with no ABOVE state must both participate without WM-specific rules. */
 for (int i=0; i<3; i++) {
  panels[i]=xcb_generate_id(c);
  uint32_t override=i==1;
  xcb_create_window(c,0,panels[i],s->root,10,10,100,100,0,
   XCB_WINDOW_CLASS_INPUT_OUTPUT,s->root_visual,XCB_CW_OVERRIDE_REDIRECT,&override);
  xcb_atom_t dock=i==2 ? e._NET_WM_WINDOW_TYPE_TOOLBAR : e._NET_WM_WINDOW_TYPE_DOCK;
  xcb_ewmh_set_wm_window_type(&e,panels[i],1,&dock);
  if(i!=1) {xcb_atom_t a=e._NET_WM_STATE_ABOVE;xcb_ewmh_set_wm_state(&e,panels[i],1,&a);}
  xcb_window_t focus=focused();xcb_map_window(c,panels[i]);settle();assert(focused()==focus);
 }
 invariant(); assert(above(3));
 layer(1,1);layer(2,2);assert(above(1));assert(!above(2));
 for(int i=0;i<4;i++) {assert(!command("focus",NULL,w[i]));assert(focused()==w[i]);invariant();}
 /* Tab-style cycling and direct unmanaged panel raises obey the same tiers. */
 for(int i=0;i<12;i++) {
  pid_t pid=fork();assert(pid>=0);
  if(!pid){execl(bin,bin,"window","cycle",(char*)NULL);_exit(127);}
  int status;assert(waitpid(pid,&status,0)==pid);assert(WIFEXITED(status)&&!WEXITSTATUS(status));
  settle();invariant();
 }
 for(int i=0;i<2;i++) {
  uint32_t raise=XCB_STACK_MODE_ABOVE;
  xcb_configure_window(c,panels[i],XCB_CONFIG_WINDOW_STACK_MODE,&raise);settle();invariant();
  xcb_unmap_window(c,panels[i]);settle();xcb_map_window(c,panels[i]);settle();invariant();
 }
 /* Real client ConfigureRequest raises/lowers, including conditional modes. */
 for(int mode=0;mode<=4;mode++) for(int i=0;i<4;i++) {
  uint32_t value=mode;xcb_configure_window(c,w[i],XCB_CONFIG_WINDOW_STACK_MODE,&value);settle();invariant();
 }
 assert(!command("focus",NULL,w[1]));assert(position(w[1])>position(w[3]));
 assert(!command("focus",NULL,w[3]));assert(position(w[3])>position(w[1]));
 assert(!command("hide",NULL,w[2]));invariant();assert(!command("focus",NULL,w[2]));invariant();
 xcb_unmap_window(c,w[2]);settle();invariant();xcb_map_window(c,w[2]);settle();invariant();
 group_command("add",w[2]);group_command("deactivate",0);invariant();
 layer(2,1);layer(2,2);group_command("activate",0);invariant();
 raise_many();invariant();assert(position(w[3])>position(w[1]));
 assert(!command("stack","cycle",w[0]));invariant();
 for(int direction=0;direction<2;direction++) {
  xcb_circulate_window(c,s->root,direction);settle();invariant();
 }
 ewmh(0,XCB_EWMH_WM_STATE_ADD);layers[0]=1;assert(above(0));invariant();
 ewmh(0,XCB_EWMH_WM_STATE_TOGGLE);layers[0]=0;assert(!above(0));invariant();
 ewmh(2,XCB_EWMH_WM_STATE_ADD);assert(!above(2));invariant();
 ewmh(2,XCB_EWMH_WM_STATE_REMOVE);assert(!above(2));invariant();
 /* Direct EWMH changes on an automatic managed client apply immediately. */
 xcb_atom_t a=e._NET_WM_STATE_ABOVE;
 xcb_ewmh_set_wm_state(&e,w[0],1,&a);settle();layers[0]=1;invariant();
 xcb_ewmh_set_wm_state(&e,w[0],0,NULL);settle();layers[0]=0;invariant();
 xcb_atom_t dock=e._NET_WM_WINDOW_TYPE_DOCK;
 xcb_ewmh_set_wm_window_type(&e,w[0],1,&dock);settle();layers[0]=1;invariant();
 /* IPC normal overrides both DOCK and future ABOVE changes, including remap. */
 layer(0,0);
 ewmh(0,XCB_EWMH_WM_STATE_ADD);assert(!above(0));invariant();
 xcb_ewmh_set_wm_state(&e,w[0],1,&a);settle();assert(!above(0));invariant();
 xcb_unmap_window(c,w[0]);settle();xcb_map_window(c,w[0]);settle();invariant();
 layer(1,1);ewmh(1,XCB_EWMH_WM_STATE_REMOVE);assert(above(1));invariant();
 /* An unmanaged ABOVE toolbar responds to EWMH without IPC rules. */
 xcb_ewmh_request_change_wm_state(&e,0,panels[2],XCB_EWMH_WM_STATE_REMOVE,
  e._NET_WM_STATE_ABOVE,XCB_NONE,XCB_EWMH_CLIENT_SOURCE_TYPE_OTHER);
 settle();panel_layers[2]=-1;invariant();
 xcb_ewmh_request_change_wm_state(&e,0,panels[2],XCB_EWMH_WM_STATE_ADD,
  e._NET_WM_STATE_ABOVE,XCB_NONE,XCB_EWMH_CLIENT_SOURCE_TYPE_OTHER);
 settle();panel_layers[2]=1;invariant();
 /* Layer changes preserve unrelated EWMH atoms. */
 xcb_atom_t sticky=e._NET_WM_STATE_STICKY;
 xcb_ewmh_set_wm_state(&e,w[0],1,&sticky);settle();layer(0,1);
 xcb_ewmh_get_atoms_reply_t states;
 assert(xcb_ewmh_get_wm_state_reply(&e,xcb_ewmh_get_wm_state(&e,w[0]),&states,NULL));
 bool has_sticky=false;for(unsigned i=0;i<states.atoms_len;i++)if(states.atoms[i]==sticky)has_sticky=true;
 assert(has_sticky);xcb_ewmh_get_atoms_reply_wipe(&states);layer(0,0);
 layer(2,0);layer(1,0);layer(3,0);assert(!above(1));assert(!above(3));
 assert(!command("focus",NULL,w[1]));
 assert(!command("layer","above",XCB_NONE));layers[1]=1;invariant();
 assert(!command("layer","normal",XCB_NONE));layers[1]=0;invariant();
 assert(command("layer","Invalid",w[0])!=0);
 assert(command("layer","Above",0xdeadbeef)!=0);
 invalid_ipc();
 layer(2,2);
 xcb_window_t old=w[2];xcb_destroy_window(c,old);settle();assert(command("layer","Above",old)!=0);
 /* Explicitly reuse an XID on this connection: no old layer survives. */
 xcb_create_window(c,0,old,s->root,50,50,200,200,0,XCB_WINDOW_CLASS_INPUT_OUTPUT,s->root_visual,0,NULL);
 layers[2]=0;xcb_map_window(c,old);settle();assert(!command("focus",NULL,old));
 /* The WM creates a fresh frame as well; compare client ordering on reuse. */
 for(int j=0;j<4;j++)if(j!=2)assert(position(old)>position(w[j]));
 for(int j=0;j<2;j++)assert(position(panels[j])>position(old));
 puts("PASS: layer ordering, focus, within-tier raises, configure/circulate, hide/remap, groups, bulk raises, EWMH defaults/overrides, docks/panels, invalid IPC/XIDs, XID reuse");
 xcb_disconnect(c);return 0;
}
