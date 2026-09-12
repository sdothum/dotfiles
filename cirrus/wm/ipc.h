// See LICENSE file for copyright and license details.

#ifndef WM_IPC_H
#define WM_IPC_H

#define ATOM_COMMAND "__WM_IPC_COMMAND"
#define ATOM_RESPONSE "__WM_IPC_RESPONSE"
#define ATOM_REQUEST "__WM_IPC_REQUEST"

#define WM_EXIT_RESTART 75

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
	IPCActionGroupActivate,
	IPCActionGroupDeactivate,
	IPCGroupRemoveAllWindows,
	IPCWindowCardinalFocus,
	IPCWindowCycle,
	IPCWindowCycleInGroup,
	IPCWindowFocus,
	IPCWindowFocusLast,
	IPCWindowRevCycle,
	IPCWindowRevCycleInGroup,
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
	IPCActionWindowReset,
	IPCActionWindowStackCycle,
	IPCActionGroupAdd,
	IPCActionGroupRemove,
	IPCWindowStack,
	IPCGroupCurrent,
	IPCWindowGroup,
	IPCWindowGroups,
	IPCWindowSnapshot,
	IPCWindowStackGeometries,
	IPCActionWindowApplyGeometries,
	IPCActionWindowRaiseMany,
	IPCActionWindowApplyGeometriesChecked,
	IPCGroupCount,
	IPCWMRestart,
	/* reply window, explicit target, XID, layer (Normal=0, Above=1, Overlay=2) */
	IPCActionWindowLayer,
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
	IPCConfigOuterBorderWidth,
	IPCConfigClickToFocus,
	IPCConfigOuterColorFocused,
	IPCConfigOuterColorUnfocused,
	IPCConfigCornerMask,
	IPCConfigCornerPercent,
	IPCConfigCursorPosition,
	IPCConfigEnableBorders,
	IPCConfigEnableLastWindowFocusing,
	IPCConfigEnableResizeHints,
	IPCConfigEnableSloppyFocus,
	IPCConfigGapWidth,
	IPCConfigGroupsNr,
	IPCConfigInnerBorderWidth,
	IPCConfigInnerColorFocused,
	IPCConfigInnerColorUnfocused,
	IPCConfigPointerActions,
	IPCConfigPointerModifier,
	IPCConfigReplayClickOnFocus,
	IPCConfigStickyWindows,
	NR_IPC_CONFIGS
};

extern void (*ipc_handlers[NR_IPC_COMMANDS])(uint32_t *);

#endif
