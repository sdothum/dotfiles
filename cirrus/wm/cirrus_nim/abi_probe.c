#include <stddef.h>
#include <stdio.h>
#include <xcb/xcb.h>
#include <xcb/xproto.h>

int main(void) {
    printf("screen=%zu screen.root=%zu screen.width=%zu screen.root_visual=%zu screen.root_depth=%zu iterator=%zu iterator.data=%zu iterator.rem=%zu iterator.index=%zu error=%zu error.error_code=%zu generic=%zu generic.response_type=%zu generic.full_sequence=%zu generic.full_sequence_size=%zu generic.full_sequence_signed=0 void_cookie=%zu void_cookie.sequence=%zu void_cookie.sequence_size=%zu atom_cookie=%zu atom_cookie.sequence=%zu atom_reply=%zu atom_reply.atom=%zu\n",
           sizeof(xcb_screen_t), offsetof(xcb_screen_t, root), offsetof(xcb_screen_t, width_in_pixels), offsetof(xcb_screen_t, root_visual), offsetof(xcb_screen_t, root_depth),
           sizeof(xcb_screen_iterator_t), offsetof(xcb_screen_iterator_t, data),
           offsetof(xcb_screen_iterator_t, rem), offsetof(xcb_screen_iterator_t, index),
           sizeof(xcb_generic_error_t), offsetof(xcb_generic_error_t, error_code),
           sizeof(xcb_generic_event_t), offsetof(xcb_generic_event_t, response_type), offsetof(xcb_generic_event_t, full_sequence), sizeof(((xcb_generic_event_t *)0)->full_sequence),
           sizeof(xcb_void_cookie_t), offsetof(xcb_void_cookie_t, sequence), sizeof(((xcb_void_cookie_t *)0)->sequence),
           sizeof(xcb_intern_atom_cookie_t), offsetof(xcb_intern_atom_cookie_t, sequence),
           sizeof(xcb_intern_atom_reply_t), offsetof(xcb_intern_atom_reply_t, atom));
    printf("query_tree_cookie=%zu query_tree_reply=%zu query_tree_reply.children_len=%zu get_window_attributes_cookie=%zu get_window_attributes_reply=%zu get_window_attributes.map_state=%zu get_window_attributes.override_redirect=%zu get_geometry_cookie=%zu get_geometry_reply=%zu get_geometry.x=%zu get_geometry.width=%zu get_property_cookie=%zu get_property_reply=%zu get_property.type=%zu get_property.value_len=%zu get_property.bytes_after=%zu\n",
           sizeof(xcb_query_tree_cookie_t), sizeof(xcb_query_tree_reply_t), offsetof(xcb_query_tree_reply_t, children_len),
           sizeof(xcb_get_window_attributes_cookie_t), sizeof(xcb_get_window_attributes_reply_t), offsetof(xcb_get_window_attributes_reply_t, map_state), offsetof(xcb_get_window_attributes_reply_t, override_redirect),
           sizeof(xcb_get_geometry_cookie_t), sizeof(xcb_get_geometry_reply_t), offsetof(xcb_get_geometry_reply_t, x), offsetof(xcb_get_geometry_reply_t, width),
           sizeof(xcb_get_property_cookie_t), sizeof(xcb_get_property_reply_t), offsetof(xcb_get_property_reply_t, type), offsetof(xcb_get_property_reply_t, value_len), offsetof(xcb_get_property_reply_t, bytes_after));
    xcb_query_pointer_reply_t pointer_reply = {0};
    pointer_reply.root_x = -1;
    printf("query_pointer_cookie=%zu query_pointer_reply=%zu query_pointer.same_screen=%zu query_pointer.root_x=%zu query_pointer.root_x_size=%zu query_pointer.root_x_signed=%d query_pointer.root_y=%zu query_pointer.root_y_size=%zu\n",
           sizeof(xcb_query_pointer_cookie_t), sizeof(xcb_query_pointer_reply_t),
           offsetof(xcb_query_pointer_reply_t, same_screen),
           offsetof(xcb_query_pointer_reply_t, root_x), sizeof(pointer_reply.root_x),
           pointer_reply.root_x < 0, offsetof(xcb_query_pointer_reply_t, root_y),
           sizeof(pointer_reply.root_y));
    printf("map_request=%zu map_request.window=%zu map_notify=%zu map_notify.window=%zu unmap_notify=%zu unmap_notify.window=%zu destroy_notify=%zu destroy_notify.window=%zu\n",
           sizeof(xcb_map_request_event_t), offsetof(xcb_map_request_event_t, window),
           sizeof(xcb_map_notify_event_t), offsetof(xcb_map_notify_event_t, window),
           sizeof(xcb_unmap_notify_event_t), offsetof(xcb_unmap_notify_event_t, window),
           sizeof(xcb_destroy_notify_event_t), offsetof(xcb_destroy_notify_event_t, window));
    xcb_enter_notify_event_t enter_event = {0};
    enter_event.root_x = -1;
    printf("configure_request=%zu configure_request.value_mask=%zu configure_notify=%zu configure_notify.above_sibling=%zu configure_notify.x=%zu property_notify=%zu property_notify.state=%zu client_message=%zu client_message.data=%zu client_data=%zu client_data.data32=%zu focus=%zu focus.mode=%zu enter_notify=%zu enter_notify.mode=%zu enter_notify.mode_size=%zu enter_notify.root_x=%zu enter_notify.root_x_size=%zu enter_notify.root_x_signed=%d enter_notify.root_y=%zu enter_notify.root_y_size=%zu\n",
           sizeof(xcb_configure_request_event_t), offsetof(xcb_configure_request_event_t, value_mask),
           sizeof(xcb_configure_notify_event_t), offsetof(xcb_configure_notify_event_t, above_sibling), offsetof(xcb_configure_notify_event_t, x),
           sizeof(xcb_property_notify_event_t), offsetof(xcb_property_notify_event_t, state),
           sizeof(xcb_client_message_event_t), offsetof(xcb_client_message_event_t, data),
           sizeof(xcb_client_message_data_t), offsetof(xcb_client_message_data_t, data32),
           sizeof(xcb_focus_in_event_t), offsetof(xcb_focus_in_event_t, mode),
           sizeof(xcb_enter_notify_event_t), offsetof(xcb_enter_notify_event_t, mode),
           sizeof(enter_event.mode), offsetof(xcb_enter_notify_event_t, root_x),
           sizeof(enter_event.root_x), enter_event.root_x < 0,
           offsetof(xcb_enter_notify_event_t, root_y), sizeof(enter_event.root_y));
    return 0;
}
