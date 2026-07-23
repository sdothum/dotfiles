// See LICENSE file for copyright and license details.

#ifndef WM_IPC_H
#define WM_IPC_H

#define ATOM_COMMAND "__WM_IPC_COMMAND"
#define ATOM_RESPONSE "__WM_IPC_RESPONSE"

#define IPC_MUL_PLUS 0
#define IPC_MUL_MINUS 1

enum IPCClientScope {
	IPCClientScopeMapped,
	IPCClientScopeAll
};

enum IPCClientSelector {
	IPCClientSelectorNone,
	IPCClientSelectorClassname,
	IPCClientSelectorName
};

enum IPCCommand {
	IPCGroupActivate,
	IPCGroupActivateSpecific,
	IPCGroupAddWindow,
	IPCGroupDeactivate,
	IPCGroupRemoveAllWindows,
	IPCGroupRemoveWindow,
	IPCGroupToggle,
	IPCWindowCardinalFocus,
	IPCWindowClose,
	IPCWindowCycle,
	IPCWindowCycleInGroup,
	IPCWindowFocus,
	IPCWindowFocusLast,
	IPCWindowHide,
	IPCWindowHorMaximize,
	IPCWindowMaximize,
	IPCWindowMonocle,
	IPCWindowMove,
	IPCWindowMoveAbsolute,
	IPCWindowMoveInGrid,
	IPCWindowPutInGrid,
	IPCWindowResize,
	IPCWindowResizeAbsolute,
	IPCWindowResizeInGrid,
	IPCWindowRevCycle,
	IPCWindowRevCycleInGroup,
	IPCWindowSnap,
	IPCWindowStackToggle,
	IPCWindowUnmaximize,
	IPCWindowVerMaximize,
	IPCWMConfig,
	IPCWMQuit,
	IPCWindowFocused,
	IPCWindowIds,
	IPCWindowCount,
	IPCWindowClassname,
	IPCWindowGeometry,
	IPCActionWindowMove,
	IPCActionWindowResize,
	IPCActionWindowMaximize,
	IPCActionWindowMonocle,
	IPCActionWindowClose,
	IPCActionWindowHide,
	IPCActionGroupAdd,
	IPCActionGroupRemove,
	NR_IPC_COMMANDS
};

enum IPCMaximizeAxis {
	IPCMaximizeFull,
	IPCMaximizeHorizontal,
	IPCMaximizeVertical
};

enum IPCConfig {
	IPCConfigApplySettings,
	IPCConfigBorderStyle,
	IPCConfigBorderWidth,
	IPCConfigClickToFocus,
	IPCConfigColorFocused,
	IPCConfigColorUnfocused,
	IPCConfigCornerMask,
	IPCConfigCornerPercent,
	IPCConfigCursorPosition,
	IPCConfigEnableBorders,
	IPCConfigEnableLastWindowFocusing,
	IPCConfigEnableResizeHints,
	IPCConfigEnableSloppyFocus,
	IPCConfigGapWidth,
	IPCConfigGridGapWidth,
	IPCConfigGroupsNr,
	IPCConfigInternalBorderWidth,
	IPCConfigInternalColorFocused,
	IPCConfigInternalColorUnfocused,
	IPCConfigPointerActions,
	IPCConfigPointerModifier,
	IPCConfigReplayClickOnFocus,
	IPCConfigStickyWindows,
	NR_IPC_CONFIGS
};

extern void (*ipc_handlers[NR_IPC_COMMANDS])(uint32_t *);

#endif
