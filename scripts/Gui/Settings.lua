--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

ADSettings = {}
ADSettings.debug = false

local ADSettings_mt = Class(ADSettings, TabbedMenu)

ADSettings.ICON_COLOR = {
    DEFAULT = {1, 1, 1, 1},
    CHANGED = {0.9910, 0.03865, 0.0100, 1}
}

function ADSettings.new(target)
    local self = TabbedMenu.new(target, ADSettings_mt)
    self:include(ADGuiDebugMixin)
    return self
end

function ADSettings:onGuiSetupFinished()
    ADSettings:superClass().onGuiSetupFinished(self)
    self:setupPages()
end

function ADSettings:setupPages()
    self:debugMsg("ADSettings:setupPages")
    local alwaysEnabled = function()
        return true
    end

    local developmentControlsEnabled = function()
        return AutoDrive.developmentControls
    end

    local vehicleEnabled = function()
        local controlledVehicle = AutoDrive.getControlledVehicle()
        if g_currentMission ~= nil and controlledVehicle ~= nil and controlledVehicle.ad ~= nil then
            return true
        end
        return false
    end

    local combineEnabled = function()
        local controlledVehicle = AutoDrive.getControlledVehicle()
        if vehicleEnabled() and (controlledVehicle and controlledVehicle.ad and controlledVehicle.ad.hasCombine) then
            return true
        end
        return false
    end

    local orderedPages = {
        {self.autoDriveVehicleSettings, vehicleEnabled, "gui.icon_options_gameSettings2", false},
        {self.autoDriveCombineUnloadSettings, combineEnabled, "ad_gui.combine", false},
        {self.autoDriveUserSettings, alwaysEnabled, "gui.wardrobe_character", false},
        {self.autoDriveGlobalSettings, alwaysEnabled, "gui.icon_options_generalSettings2", false},
        {self.autoDriveEnvironmentSettings, vehicleEnabled, "gui.icon_weather_partiallyCloudy", false},
        {self.autoDriveDebugSettings, developmentControlsEnabled, "ad_gui_debug.settings_debug", true},
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, sliceId, isAutonomous = table.unpack(pageDef)
        self:registerPage(page, i, predicate)
        self:addPageTab(page, nil, nil, sliceId)
                
        page.isAutonomous = isAutonomous
        if page.setupMenuButtonInfo ~= nil then
            page:setupMenuButtonInfo(self)
        end
    end
end

function ADSettings:onOpen()
    self:debugMsg("ADSettings:onOpen")
    ADSettings:superClass().onOpen(self)
    self.inputDisableTime = 200
end

function ADSettings:onClose()
    self:debugMsg("ADSettings:onClose")
    for page, _ in pairs(self.pageTabs) do
        self:resetPage(page)
    end
    AutoDrive.Hud.lastUIScale = 0
    ADSettings:superClass().onClose(self)
end

--- Define default properties and retrieval collections for menu buttons.
function ADSettings:setupMenuButtonInfo()
    self.defaultMenuButtonInfo = {
        {inputAction = InputAction.MENU_BACK, text = g_i18n:getText("button_back"), callback = self:makeSelfCallback(self.onClickBack), showWhenPaused = true},
        {inputAction = InputAction.MENU_ACCEPT, text = g_i18n:getText("button_apply"), callback = self:makeSelfCallback(self.onClickOK), showWhenPaused = true},
        {inputAction = InputAction.MENU_CANCEL, text = g_i18n:getText("button_reset"), callback = self:makeSelfCallback(self.onClickReset), showWhenPaused = true},
        {inputAction = InputAction.MENU_ACTIVATE, text = g_i18n:getText("gui_ad_restoreButtonText"), callback = self:makeSelfCallback(self.onClickRestore), showWhenPaused = true},
        {inputAction = InputAction.MENU_EXTRA_1, text = g_i18n:getText("gui_ad_setDefaultButtonText"), callback = self:makeSelfCallback(self.onClickSetDefault), showWhenPaused = true}
    }
end

function ADSettings:onClickOK()
    self:debugMsg("ADSettings:onClickOK")
    self:applySettings()
    ADSettings:superClass().onClickBack(self)
end

function ADSettings:onClickBack()
    self:debugMsg("ADSettings:onClickBack")
    if self:pagesHasChanges() then
        AutoDrive.showYesNoDialog(
            g_i18n:getText("gui_ad_settingsClosingDialog_title"),
            g_i18n:getText("gui_ad_settingsClosingDialog_text"),
            self.onClickBackDialogCallback,
            self
        )
    else
        self:onClickBackDialogCallback(true)
    end
end

function ADSettings:onClickBackDialogCallback(yes)
    if yes then
        g_gui:changeScreen(nil)
    end
end

function ADSettings:onClickReset()
    self:debugMsg("ADSettings:onClickReset")
    if self.currentPage == nil or self.currentPage.isAutonomous then
        return
    end
    self:resetPage(self.currentPage)
end

function ADSettings:onClickRestore()
    self:debugMsg("ADSettings:onClickRestore")
    if self.currentPage == nil or self.currentPage.isAutonomous then
        return
    end
    self:restorePage(self.currentPage)
end

function ADSettings:onClickSetDefault()
    self:debugMsg("ADSettings:onClickSetDefault")
    if self:pagesHasChanges() then
        local controlledVehicle = AutoDrive.getControlledVehicle()
        for settingName, setting in pairs(AutoDrive.settings) do
            local newSetting = setting
            if setting.isVehicleSpecific and controlledVehicle ~= nil and controlledVehicle.ad ~= nil and controlledVehicle.ad.settings[settingName] ~= nil then
                newSetting = controlledVehicle.ad.settings[settingName]
                if controlledVehicle.ad.settings[settingName].new ~= nil then
                    controlledVehicle.ad.settings[settingName].current = controlledVehicle.ad.settings[settingName].new
                end
                if (not newSetting.isUserSpecific) and newSetting.new ~= nil and newSetting.new ~= setting.userDefault then
                    -- We could even print this with our debug system, but since GIANTS itself prints every changed config, for the moment we will do the same
                    -- Logging.info('Default setting \'%s\' changed from "%s" to "%s"', settingName, setting.values[setting.userDefault], setting.values[newSetting.new])
                    setting.userDefault = newSetting.new
                end
            end            
        end
        AutoDriveUpdateSettingsEvent.sendEvent(controlledVehicle)
    end
end

function ADSettings:applySettings()
    if self:pagesHasChanges() then
        self:debugMsg("ADSettings:applySettings with changes")
        local userSpecificHasChanges = false
        local controlledVehicle = AutoDrive.getControlledVehicle()

        for settingName, setting in pairs(AutoDrive.settings) do
            if setting.isVehicleSpecific and controlledVehicle ~= nil and controlledVehicle.ad ~= nil and controlledVehicle.ad.settings[settingName] ~= nil then
                setting = controlledVehicle.ad.settings[settingName]
            end
            if setting.new ~= nil and setting.new ~= setting.current then
                -- We could even print this with our debug system, but since GIANTS itself prints every changed config, for the moment we will do the same
                -- Logging.info('Setting \'%s\' changed from "%s" to "%s"', settingName, setting.values[setting.current], setting.values[setting.new])
                setting.current = setting.new
                if setting.isUserSpecific then
                    userSpecificHasChanges = true
                end
            end
        end

        if userSpecificHasChanges then
            AutoDrive.setEditorMode(AutoDrive.EDITOR_OFF)
            ADUserDataManager:sendToServer()
        end

        AutoDriveUpdateSettingsEvent.sendEvent(controlledVehicle)
    end
end

function ADSettings:resetPage(page)
    if page == nil or page.isAutonomous then
        return
    end
    if page:hasChanges() then
        self:debugMsg("ADSettings:resetPage with changes")
        local controlledVehicle = AutoDrive.getControlledVehicle()
        for settingName, _ in pairs(page.settingElements) do
            if AutoDrive.settings[settingName] ~= nil then
                local setting = AutoDrive.settings[settingName]
                if setting.isVehicleSpecific and controlledVehicle ~= nil and controlledVehicle.ad ~= nil and controlledVehicle.ad.settings[settingName] ~= nil then
                    setting = controlledVehicle.ad.settings[settingName]
                end
                setting.new = setting.current
                page:loadGUISetting(settingName, setting.current)
            end
        end
    end
end

function ADSettings:restorePage(page)
    if page == nil or page.isAutonomous then
        return
    end
    local controlledVehicle = AutoDrive.getControlledVehicle()
    for settingName, _ in pairs(page.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            if setting.isVehicleSpecific and controlledVehicle ~= nil and controlledVehicle.ad ~= nil and controlledVehicle.ad.settings[settingName] ~= nil then
                setting = controlledVehicle.ad.settings[settingName]
            end

            if AutoDrive.settings[settingName].userDefault ~= nil then
                setting.new = AutoDrive.settings[settingName].userDefault
            else
                setting.new = setting.default
            end
            page:loadGUISetting(settingName, setting.new)
        end
    end
end

function ADSettings:pagesHasChanges()
    for page, _ in pairs(self.pageTabs) do
        if not page.isAutonomous and page:hasChanges() then
            return true
        end
    end
    return false
end

function ADSettings:forceLoadGUISettings()
    for page, _ in pairs(self.pageTabs) do
        if page.loadGUISettings ~= nil then
            page:loadGUISettings()
        end
    end
end
