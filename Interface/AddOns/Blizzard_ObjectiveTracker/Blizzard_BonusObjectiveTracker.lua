BonusObjectiveTrackerModuleMixin = {};

function CreateBonusObjectiveTrackerModule()
	local module = Mixin(ObjectiveTracker_GetModuleInfoTable(), BonusObjectiveTrackerModuleMixin);

	module.blockTemplate = "BonusObjectiveTrackerBlockTemplate";
	module.blockType = "ScrollFrame";
	module.freeBlocks = { };
	module.usedBlocks = { };
	module.freeLines = { };
	module.lineTemplate = "BonusObjectiveTrackerLineTemplate";
	module.blockOffsetX = -20;
	module.blockOffsetY = -6;
	module.fromHeaderOffsetY = -8;
	module.blockPadding = 3;	-- need some extra room so scrollframe doesn't cut tails off gjpqy

	return module;
end

local COMPLETED_BONUS_DATA = { };
local COMPLETED_SUPERSEDED_BONUS_OBJECTIVES = { };
-- this is to track which bonus objective is playing in the banner and shouldn't be in the tracker yet
-- if multiple bonus objectives are added at the same time, only one will be in the banner 
local BANNER_BONUS_OBJECTIVE_ID;

function BonusObjectiveTrackerModuleMixin:OnFreeBlock(block)
	if ( block.state == "LEAVING" ) then
		block.AnimOut:Stop();
	elseif ( block.state == "ENTERING" ) then
		block.AnimIn:Stop();
	end
	if ( COMPLETED_BONUS_DATA[block.id] ) then
		COMPLETED_BONUS_DATA[block.id] = nil;
		local rewardsFrame = block.module.rewardsFrame;
		if ( rewardsFrame.id == block.id ) then
			rewardsFrame:Hide();
			rewardsFrame.Anim:Stop();
			rewardsFrame.id = nil;
			for i = 1, #rewardsFrame.Rewards do
				rewardsFrame.Rewards[i].Anim:Stop();
			end
		end
	end
	local itemButton = block.itemButton;
	if ( itemButton ) then
		QuestObjectiveItem_ReleaseButton(itemButton);
		block.itemButton = nil;
	end
	if (block.id < 0) then
		local blockKey = -block.id;
		if (BonusObjectiveTracker_GetSupersedingStep(blockKey)) then
			tinsert(COMPLETED_SUPERSEDED_BONUS_OBJECTIVES, blockKey);
		end
	end
	block:SetAlpha(0);	
	block.state = nil;
	block.finished = nil;
	block.posIndex = nil;
end

function BonusObjectiveTrackerModuleMixin:OnFreeLine(line)
	if ( line.finished ) then
		line.CheckFlash.Anim:Stop();
		line.finished = nil;
	end
end

-- *****************************************************************************************************
-- ***** FRAME HANDLERS
-- *****************************************************************************************************

function BonusObjectiveTracker_OnHeaderLoad(self)
	local module = CreateBonusObjectiveTrackerModule();
	
	module.rewardsFrame = self.RewardsFrame;
	module.ShowWorldQuests = self.ShowWorldQuests;
	module.DefaultHeaderText = self.DefaultHeaderText;

	if ( module.ShowWorldQuests ) then
		module.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_WORLD_QUEST;
		module.updateReasonEvents = OBJECTIVE_TRACKER_UPDATE_QUEST + OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED + OBJECTIVE_TRACKER_UPDATE_SUPER_TRACK_CHANGED;
	else
		module.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_BONUS_OBJECTIVE;
		module.updateReasonEvents = OBJECTIVE_TRACKER_UPDATE_QUEST + OBJECTIVE_TRACKER_UPDATE_TASK_ADDED + OBJECTIVE_TRACKER_UPDATE_SCENARIO + OBJECTIVE_TRACKER_UPDATE_SCENARIO_NEW_STAGE + OBJECTIVE_TRACKER_UPDATE_SCENARIO_BONUS_DELAYED;
	end

	self.module = module;
	_G[self.ModuleName] = module;
	self.RewardsFrame.module = module;
	

	self.module:SetHeader(self, module.DefaultHeaderText, 0);
	self.height = OBJECTIVE_TRACKER_HEADER_HEIGHT;
	
	self:RegisterEvent("CRITERIA_COMPLETE");
end

function BonusObjectiveTracker_OnBlockAnimInFinished(self)
	local block = self:GetParent();
	block:SetAlpha(1);
	block.state = "PRESENT";
	-- negative block IDs are for scenario bonus objectives
	if ( block.id > 0 ) then
		local isInArea, isOnMap = GetTaskInfo(block.id);
		if ( not isInArea ) then
			ObjectiveTracker_Update(block.module.updateReasonModule);
			return;
		end
	end
	for _, line in pairs(block.lines) do
		line.Glow.Anim:Play();
	end
end

function BonusObjectiveTracker_OnBlockAnimOutFinished(self)
	local block = self:GetParent();
	block:SetAlpha(0);
	block.used = nil;
	block.module:FreeBlock(block);
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_ALL);
end

function BonusObjectiveTracker_OnBlockEnter(block)
	block.module:OnBlockHeaderEnter(block);
	BonusObjectiveTracker_ShowRewardsTooltip(block);
end

function BonusObjectiveTracker_OnBlockLeave(block)
	block.module:OnBlockHeaderLeave(block);
	GameTooltip:Hide();
	block.module.tooltipBlock = nil;
end

function BonusObjectiveTracker_TrackWorldQuest(questID)
	AddWorldQuestWatch(questID);
	SetSuperTrackedQuestID(questID);
end

function BonusObjectiveTracker_UntrackWorldQuest(questID)
	RemoveWorldQuestWatch(questID);
	if questID == GetSuperTrackedQuestID() then
		QuestSuperTracking_ChooseClosestQuest();
	end
end

function BonusObjectiveTracker_OnBlockClick(self, button)
	if button == "LeftButton" then
		if IsShiftKeyDown() then
			BonusObjectiveTracker_UntrackWorldQuest(self.TrackedQuest.questID);
		end
	elseif button == "RightButton" then
		ObjectiveTracker_ToggleDropDown(self, BonusObjectiveTracker_OnOpenDropDown);
	end
end

function BonusObjectiveTracker_OnOpenDropDown(self)
	local block = self.activeFrame;
	local questID = block.TrackedQuest.questID;

	local info = UIDropDownMenu_CreateInfo();
	info.notCheckable = true;

	info.text = OBJECTIVES_STOP_TRACKING;
	info.func = function()
		BonusObjectiveTracker_UntrackWorldQuest(questID);
	end;

	info.checked = false;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
end

function BonusObjectiveTracker_OnEvent(self, event, ...)
	if ( event == "CRITERIA_COMPLETE" and not ObjectiveTrackerFrame.collapsed ) then
		local id = ...;
		if( id > 0 ) then
			local tblBonusSteps = C_Scenario.GetBonusSteps();
			for i = 1, #tblBonusSteps do
				local bonusStepIndex = tblBonusSteps[i];
				local _, _, numCriteria = C_Scenario.GetStepInfo(bonusStepIndex);
				local blockKey = -bonusStepIndex;	-- so it won't collide with quest IDs
				local block = self.module:GetBlock(blockKey);
				if( block ) then
					for criteriaIndex = 1, numCriteria do
						local _, _, _, _, _, _, _, _, criteriaID = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex);		
						if( id == criteriaID ) then
							local questID = C_Scenario.GetBonusStepRewardQuestID(bonusStepIndex);
							if ( questID ~= 0 ) then
								BonusObjectiveTracker_AddReward(questID, block);
								return;
							end
						end
					end
				end
			end
		end
	end
end

-- *****************************************************************************************************
-- ***** REWARD FUNCTIONS
-- *****************************************************************************************************

function BonusObjectiveTracker_OnTaskCompleted(questID, xp, money)
	-- make sure we're already displaying this
	local block = BONUS_OBJECTIVE_TRACKER_MODULE:GetExistingBlock(questID);
	if ( block ) then
		BonusObjectiveTracker_AddReward(questID, block, xp, money);
	end

	local block = WORLD_QUEST_TRACKER_MODULE:GetExistingBlock(questID);
	if ( block ) then
		-- Don't animate rewards on WQs, toast instead
		WorldQuestCompleteAlertSystem:AddAlert(questID);
	end
end

function BonusObjectiveTracker_AddReward(questID, block, xp, money)
	-- cancel any entering/leaving animations
	BonusObjectiveTracker_SetBlockState(block, "PRESENT", true);

	local data = { };
	-- save data for a quest
	if ( block.id > 0 ) then
		data.posIndex = block.posIndex;
		data.objectives = { };
		local isInArea, isOnMap, numObjectives, taskName, displayAsObjective = GetTaskInfo(questID);
		for objectiveIndex = 1, numObjectives do
			local text, objectiveType, finished = GetQuestObjectiveInfo(questID, objectiveIndex, true);
			tinsert(data.objectives, text);
			data.objectiveType = objectiveType;
		end
		data.taskName = taskName;
		data.displayAsObjective = displayAsObjective;
	end
	-- save all the rewards
	data.rewards = { };
	-- xp
	if ( not xp ) then
		xp = GetQuestLogRewardXP(questID);
	end
	if ( xp > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
		local t = { };
		t.label = xp;
		t.texture = "Interface\\Icons\\XP_Icon";
		t.count = 0;
		t.font = "NumberFontNormal";
		tinsert(data.rewards, t);
	end

	local artifactXP, artifactCategory = GetQuestLogRewardArtifactXP(questID);
	if ( artifactXP > 0 ) then
		local name, icon = C_ArtifactUI.GetArtifactXPRewardTargetInfo(artifactCategory);
		local t = { };
		t.label = artifactXP;
		t.texture = icon or "Interface\\Icons\\INV_Misc_QuestionMark";
		t.overlay = "Interface\\Artifacts\\ArtifactPower-QuestBorder";
		t.count = 0;
		t.font = "NumberFontNormal";
		tinsert(data.rewards, t);
	end
	-- currencies
	local numCurrencies = GetNumQuestLogRewardCurrencies(questID);
	for i = 1, numCurrencies do
		local name, texture, count = GetQuestLogRewardCurrencyInfo(i, questID);
		local t = { };
		t.label = name;
		t.texture = texture;
		t.count = count;
		t.font = "GameFontHighlightSmall";
		tinsert(data.rewards, t);
	end
	-- items
	local numItems = GetNumQuestLogRewards(questID);
	for i = 1, numItems do
		local name, texture, count, quality, isUsable = GetQuestLogRewardInfo(i, questID);
		local t = { };
		t.label = name;
		t.texture = texture;
		t.count = count;
		t.font = "GameFontHighlightSmall";
		tinsert(data.rewards, t);
	end	
	-- money
	if ( not money ) then
		money = GetQuestLogRewardMoney(questID);
	end
	if ( money > 0 ) then
		local t = { };
		t.label = GetMoneyString(money);
		t.texture = "Interface\\Icons\\inv_misc_coin_01";
		t.count = 0;
		t.font = "GameFontHighlight";
		tinsert(data.rewards, t);
	end
	COMPLETED_BONUS_DATA[block.id] = data;
	-- try to play it
	if( #data.rewards > 0 ) then
		BonusObjectiveTracker_AnimateReward(block);
	else
		local oldPosIndex = COMPLETED_BONUS_DATA[block.id].posIndex;
		COMPLETED_BONUS_DATA[block.id] = nil;
		BonusObjectiveTracker_OnAnimateNextReward(block.module, oldPosIndex);
	end
end

function BonusObjectiveTracker_AnimateReward(block)
	local rewardsFrame = block.module.rewardsFrame;
	if ( not rewardsFrame.id ) then
		local data = COMPLETED_BONUS_DATA[block.id];
		if ( not data ) then
			return;
		end

		rewardsFrame.id = block.id;
		rewardsFrame:SetParent(block);
		rewardsFrame:ClearAllPoints();
		rewardsFrame:SetPoint("TOPRIGHT", block, "TOPLEFT", 10, -4);
		rewardsFrame:Show();
		local numRewards = #data.rewards;
		local contentsHeight = 12 + numRewards * 36;
		rewardsFrame.Anim.RewardsBottomAnim:SetOffset(0, -contentsHeight);
		rewardsFrame.Anim.RewardsShadowAnim:SetToScale(0.8, contentsHeight / 16);
		rewardsFrame.Anim:Play();
		PlaySoundKitID(45142); --UI_BonusEventSystemVignettes
		-- configure reward frames
		for i = 1, numRewards do
			local rewardItem = rewardsFrame.Rewards[i];
			if ( not rewardItem ) then
				rewardItem = CreateFrame("FRAME", nil, rewardsFrame, "BonusObjectiveTrackerRewardTemplate");
				rewardItem:SetPoint("TOPLEFT", rewardsFrame.Rewards[i-1], "BOTTOMLEFT", 0, -4);
			end
			local rewardData = data.rewards[i];
			if ( rewardData.count > 1 ) then
				rewardItem.Count:Show();
				rewardItem.Count:SetText(rewardData.count);				
			else
				rewardItem.Count:Hide();
			end
			rewardItem.Label:SetFontObject(rewardData.font);
			rewardItem.Label:SetText(rewardData.label);
			rewardItem.ItemIcon:SetTexture(rewardData.texture);
			if ( rewardData.overlay ) then
				rewardItem.ItemOverlay:SetTexture(rewardData.overlay);
				rewardItem.ItemOverlay:Show();
			else
				rewardItem.ItemOverlay:Hide();
			end
			rewardItem:Show();
			if( rewardItem.Anim:IsPlaying() ) then
				rewardItem.Anim:Stop();
			end
			rewardItem.Anim:Play();
		end
		-- hide unused reward items
		for i = numRewards + 1, #rewardsFrame.Rewards do
			rewardsFrame.Rewards[i]:Hide();
		end
	end
end

function BonusObjectiveTracker_OnAnimateRewardDone(self)
	local rewardsFrame = self:GetParent();
	-- kill the data
	local oldPosIndex = COMPLETED_BONUS_DATA[rewardsFrame.id].posIndex;
	COMPLETED_BONUS_DATA[rewardsFrame.id] = nil;
	rewardsFrame.id = nil;
	
	BonusObjectiveTracker_OnAnimateNextReward(rewardsFrame.module, oldPosIndex);
end

function BonusObjectiveTracker_OnAnimateNextReward(module, oldPosIndex)
	local rewardsFrame = module.rewardsFrame;
	-- look for another reward to animate and fix positions
	local nextAnimBlock;
	for id, data in pairs(COMPLETED_BONUS_DATA) do
		local block = module:GetExistingBlock(id);
		-- make sure we're still showing this
		if ( block ) then
			nextAnimBlock = block;
			-- if this block that completed was ahead of this, bring it up
			if ( data.posIndex > oldPosIndex ) then
				data.posIndex = data.posIndex - 1;
			end
		end
	end
	-- update tracker to remove dead bonus objective
	ObjectiveTracker_Update(module.updateReasonModule);
	-- animate if we have something, otherwise clear it all
	if ( nextAnimBlock ) then
		BonusObjectiveTracker_AnimateReward(nextAnimBlock);
	else
		rewardsFrame:Hide();
		wipe(COMPLETED_BONUS_DATA);
	end
end

function BonusObjectiveTracker_ShowRewardsTooltip(block)
	local questID;
	if ( block.id < 0 ) then
		-- this is a scenario bonus objective
		questID = C_Scenario.GetBonusStepRewardQuestID(-block.id);
		if ( questID == 0 ) then
			-- huh, no reward
			return;
		end
	else
		questID = block.id;
		if ( COMPLETED_BONUS_DATA[questID] ) then
			-- no tooltip for completed objectives
			return;
		end
	end

	if ( HaveQuestData(questID) and GetQuestLogRewardXP(questID) == 0 and GetNumQuestLogRewardCurrencies(questID) == 0
								and GetNumQuestLogRewards(questID) == 0 and GetQuestLogRewardMoney(questID) == 0 and GetQuestLogRewardArtifactXP(questID) == 0 ) then
		GameTooltip:Hide();
		return;
	end

	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("TOPRIGHT", block, "TOPLEFT", 0, 0);
	GameTooltip:SetOwner(block, "ANCHOR_PRESERVE");
	GameTooltip:SetText(REWARDS, 1, 0.831, 0.380);

	if ( not HaveQuestData(questID) ) then
		GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	else	
		local isWorldQuest = block.module.ShowWorldQuests;
		GameTooltip:AddLine(isWorldQuest and WORLD_QUEST_TOOLTIP_DESCRIPTION or BONUS_OBJECTIVE_TOOLTIP_DESCRIPTION, 1, 1, 1, 1);
		GameTooltip:AddLine(" ");
		-- xp
		local xp = GetQuestLogRewardXP(questID);
		if ( xp > 0 ) then
			GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1);
		end
		local artifactXP = GetQuestLogRewardArtifactXP(questID);
		if ( artifactXP > 0 ) then
			GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_ARTIFACT_XP_FORMAT, artifactXP), 1, 1, 1);
		end
		-- currency		
		local numQuestCurrencies = GetNumQuestLogRewardCurrencies(questID);
		for i = 1, numQuestCurrencies do
			local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, questID);
			local text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
			GameTooltip:AddLine(text, 1, 1, 1);			
		end
		-- items
		local numQuestRewards = GetNumQuestLogRewards(questID);
		for i = 1, numQuestRewards do
			local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i, questID);
			local text;
			if ( numItems > 1 ) then
				text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
			elseif( texture and name ) then
				text = string.format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name);			
			end
			if( text ) then
				local color = ITEM_QUALITY_COLORS[quality];
				GameTooltip:AddLine(text, color.r, color.g, color.b);
			end
		end
		-- money
		local money = GetQuestLogRewardMoney(questID);
		if ( money > 0 ) then
			SetTooltipMoney(GameTooltip, money, nil);
		end
	end
	GameTooltip:Show();
	block.module.tooltipBlock = block;
end

-- *****************************************************************************************************
-- ***** INTERNAL FUNCTIONS - blending present and past data (future data nyi)
-- *****************************************************************************************************

local function InternalGetTasksTable()
	local tasks = GetTasksTable();
	for i = 1, #tasks do
		if ( tasks[i] == BANNER_BONUS_OBJECTIVE_ID ) then
			tremove(tasks, i);
			break;
		end
	end
	for questID, data in pairs(COMPLETED_BONUS_DATA) do
		if ( questID > 0 ) then
			local found = false;
			for i = 1, #tasks do
				if ( tasks[i] == questID ) then
					found = true;
					break;
				end
			end
			if ( not found ) then
				if ( data.posIndex <= #tasks ) then
					tinsert(tasks, data.posIndex, questID);
				else
					tinsert(tasks, questID);
				end
			end
		end
	end
	return tasks;
end

local function InternalGetTaskInfo(questID)
	if ( COMPLETED_BONUS_DATA[questID] ) then
		return true, true, #COMPLETED_BONUS_DATA[questID].objectives, COMPLETED_BONUS_DATA[questID].taskName, COMPLETED_BONUS_DATA[questID].displayAsObjective;
	else
		return GetTaskInfo(questID);
	end
end

local function InternalGetQuestObjectiveInfo(questID, objectiveIndex)
	if ( COMPLETED_BONUS_DATA[questID] ) then
		return COMPLETED_BONUS_DATA[questID].objectives[objectiveIndex], COMPLETED_BONUS_DATA[questID].objectiveType, true;
	else
		return GetQuestObjectiveInfo(questID, objectiveIndex, false);
	end
end

-- *****************************************************************************************************
-- ***** UPDATE FUNCTIONS
-- *****************************************************************************************************

function BonusObjectiveTracker_GetSupersedingStep(index)
	local supersededObjectives = C_Scenario.GetSupersededObjectives();
	for i = 1, #supersededObjectives do
		local pairs = supersededObjectives[i];
		local k,v = unpack(pairs);

		if (v == index) then
			return k;
		end
	end
end

local function UpdateScenarioBonusObjectives(module)
	if ( C_Scenario.IsInScenario() ) then
		module.Header.animateReason = OBJECTIVE_TRACKER_UPDATE_SCENARIO_NEW_STAGE + OBJECTIVE_TRACKER_UPDATE_SCENARIO_BONUS_DELAYED;
		local tblBonusSteps = C_Scenario.GetBonusSteps();
		-- two steps
		local supersededToRemove = {};
		for i = 1, #tblBonusSteps do
			local bonusStepIndex = tblBonusSteps[i];
			local supersededIndex = BonusObjectiveTracker_GetSupersedingStep(bonusStepIndex);
			if (supersededIndex) then
				local name, description, numCriteria, stepFailed, isBonusStep, isForCurrentStepOnly = C_Scenario.GetStepInfo(bonusStepIndex);
				local completed = true;
				for criteriaIndex = 1, numCriteria do
					local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex);
					if ( criteriaString ) then
						if ( not criteriaCompleted ) then
							completed = false;
							break;
						end
					end
				end
				if (not completed) then
					-- B supercedes A, A is not completed, show A but not B
					tinsert(supersededToRemove, supersededIndex);
				else
					if (tContains(COMPLETED_SUPERSEDED_BONUS_OBJECTIVES, bonusStepIndex)) then
						tinsert(supersededToRemove, bonusStepIndex);
					end
				end
			end
		end
		for i = 1, #supersededToRemove do
			tDeleteItem(tblBonusSteps, supersededToRemove[i]);
		end

		for i = 1, #tblBonusSteps do
			local bonusStepIndex = tblBonusSteps[i];
			local name, description, numCriteria, stepFailed, isBonusStep, isForCurrentStepOnly = C_Scenario.GetStepInfo(bonusStepIndex);
			local blockKey = -bonusStepIndex;	-- so it won't collide with quest IDs
			local existingBlock = module:GetExistingBlock(blockKey);
			local block = module:GetBlock(blockKey);			
			local stepFinished = true;
			for criteriaIndex = 1, numCriteria do
				local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex);		
				if ( criteriaString ) then
					if (not isWeightedProgress) then
						criteriaString = string.format("%d/%d %s", quantity, totalQuantity, criteriaString);
					end
					if ( criteriaCompleted ) then
						local existingLine = block.lines[criteriaIndex];
						module:AddObjective(block, criteriaIndex, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE, OBJECTIVE_TRACKER_COLOR["Complete"]);
						local line = block.currentLine;
						if ( existingLine and not line.finished ) then
							line.Glow.Anim:Play();
							line.Sheen.Anim:Play();
						end
						line.finished = true;
					elseif ( criteriaFailed ) then
						stepFinished = false;
						module:AddObjective(block, criteriaIndex, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE, OBJECTIVE_TRACKER_COLOR["Failed"]);
					else
						stepFinished = false;
						module:AddObjective(block, criteriaIndex, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE);
					end
					-- timer bar
					if ( duration > 0 and elapsed <= duration and not (criteriaFailed or criteriaCompleted) ) then
						module:AddTimerBar(block, block.currentLine, duration, GetTime() - elapsed);
					elseif ( block.currentLine.TimerBar ) then
						module:FreeTimerBar(block, block.currentLine);
					end
					if ( criteriaIndex > 1 ) then
						local line = block.currentLine;
						line.Icon:Hide();
					end
				end
			end
			-- first line is going to display an icon
			local firstLine = block.lines[1];
			if ( firstLine ) then
				if ( stepFailed ) then
					firstLine.Icon:SetAtlas("Objective-Fail", true);
				elseif ( stepFinished ) then
					firstLine.Icon:SetAtlas("Tracker-Check", true);
					-- play anim if needed
					if ( existingBlock and not block.finished ) then
						firstLine.CheckFlash.Anim:Play();
						if (BonusObjectiveTracker_GetSupersedingStep(bonusStepIndex)) then
							BonusObjectiveTracker_SetBlockState(block, "FINISHED");
						end
					end
					block.finished = true;
				else
					firstLine.Icon:SetAtlas("Objective-Nub", true);
				end
				firstLine.Icon:Show();
			end
			block:SetHeight(block.height + module.blockPadding);

			if ( not ObjectiveTracker_AddBlock(block) ) then
				-- there was no room to show the header and the block, bail
				block.used = false;
				break;
			end

			block:Show();
			module:FreeUnusedLines(block);

			if ( block.state ~= "FINISHED" ) then
				if ( not existingBlock and isForCurrentStepOnly ) then
					BonusObjectiveTracker_SetBlockState(block, "ENTERING");
				else
					BonusObjectiveTracker_SetBlockState(block, "PRESENT");
				end
			end	
		end
	else
		wipe(COMPLETED_SUPERSEDED_BONUS_OBJECTIVES);
	end
end

local function TryAddingTimeLeftLine(module, block, questID)
	if ( C_TaskQuest.GetQuestTimeLeftMinutes(questID) ) then
		local function GetTimeLeftString()
			local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questID);
			if ( timeLeftMinutes > 0 and timeLeftMinutes < WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
				local timeString = SecondsToTime(timeLeftMinutes * 60);
				return BONUS_OBJECTIVE_TIME_LEFT:format(timeString)
			end
			return " ";
		end

		module:AddObjective(block, "TimeLeft", GetTimeLeftString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["TimeLeft"]);
		block.currentLine.Icon:Hide();
	end
end

local function AddBonusObjectiveQuest(module, questID, posIndex, isTrackedWorldQuest)
	local isInArea, isOnMap, numObjectives, taskName, displayAsObjective = InternalGetTaskInfo(questID);
	local treatAsInArea = isTrackedWorldQuest or isInArea;
	local isSuperTracked = questID == GetSuperTrackedQuestID();
	-- show task if we're in the area or on the same map and we were displaying it before
	local existingTask = module:GetExistingBlock(questID);
	if ( numObjectives and ( treatAsInArea or ( isOnMap and existingTask ) ) ) then
		local block = module:GetBlock(questID);
		-- module header?
		if ( displayAsObjective and not module.ShowWorldQuests ) then
			module.headerText = TRACKER_HEADER_OBJECTIVE;
		end

		-- check if there's an item
		local questLogIndex = GetQuestLogIndexByID(questID);
		local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex);
		local itemButton = block.itemButton;	
		if ( item and ( not isQuestComplete or showItemWhenComplete ) ) then
			-- if the block doesn't already have an item, get one
			if ( not itemButton ) then
				itemButton = QuestObjectiveItem_AcquireButton(block);
				block.itemButton = itemButton;
				itemButton:SetPoint("TOPRIGHT", block, -2, 1);
				itemButton:Show();
			end

			QuestObjectiveItem_Initialize(itemButton, questLogIndex);

			block.lineWidth = OBJECTIVE_TRACKER_TEXT_WIDTH - OBJECTIVE_TRACKER_ITEM_WIDTH;
		else
			if ( itemButton ) then
				QuestObjectiveItem_ReleaseButton(itemButton);
				block.itemButton = nil;
			end
		end

		-- block header? add it as objectiveIndex 0
		if ( taskName ) then
			module:AddObjective(block, 0, taskName, nil, nil, OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE, OBJECTIVE_TRACKER_COLOR["Header"]);
		end

		if QuestMapFrame_IsQuestWorldQuest(questID) then
			local tagID, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex = GetQuestTagInfo(questID);
			assert(worldQuestType);

			local inProgress = GetQuestLogIndexByID(questID) ~= 0;
			WorldMap_SetupWorldQuestButton(block.TrackedQuest, worldQuestType, isRare, isElite, tradeskillLineIndex, inProgress, isSuperTracked);

			block.TrackedQuest:SetScale(.9);
			block.TrackedQuest:SetPoint("TOPRIGHT", block.currentLine, "TOPLEFT", 18, 0);
			block.TrackedQuest:Show();

			block.TrackedQuest.questID = questID;
		else
			block.TrackedQuest:Hide();
		end

		local taskFinished = true;
		local hasAddedTimeLeft = false;
		for objectiveIndex = 1, numObjectives do
			local text, objectiveType, finished = InternalGetQuestObjectiveInfo(questID, objectiveIndex);
			if ( text ) then
				if ( finished ) then
					local existingLine = block.lines[objectiveIndex];
					module:AddObjective(block, objectiveIndex, text, nil, nil, OBJECTIVE_DASH_STYLE_SHOW, OBJECTIVE_TRACKER_COLOR["Complete"]);
					local line = block.currentLine;
					if ( existingLine and not line.finished ) then
						line.Glow.Anim:Play();
						line.Sheen.Anim:Play();
					end
					line.finished = true;
				else
					taskFinished = false;
					module:AddObjective(block, objectiveIndex, text, nil, nil, OBJECTIVE_DASH_STYLE_SHOW);
				end
				if ( objectiveIndex > 1 ) then
					local line = block.currentLine;
					line.Icon:Hide();
				end
			end
			if ( objectiveType == "progressbar" ) then
				if ( module.ShowWorldQuests and not hasAddedTimeLeft ) then
					-- Add time left (if any) right before the progress bar
					TryAddingTimeLeftLine(module, block, questID);
					hasAddedTimeLeft = true;
				end

				local progressBar = module:AddProgressBar(block, block.currentLine, questID, finished);
				if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_TASK_ADDED or OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED ) then
					progressBar.Bar.AnimIn:Play();
				end
			end
		end
		if ( module.ShowWorldQuests and not hasAddedTimeLeft ) then
			-- No progress bar, try adding it at the end
			TryAddingTimeLeftLine(module, block, questID);
		end
		-- first line might display the check
		local firstLine = block.lines[0] or block.lines[1];
		if ( firstLine ) then
			if ( taskFinished ) then
				firstLine.Icon:SetAtlas("Tracker-Check", true);
				-- play anim if needed
				if ( existingTask and not block.finished ) then
					firstLine.CheckFlash.Anim:Play();
				end
				block.finished = true;
				firstLine.Icon:Show();
			else
				firstLine.Icon:Hide();
			end
		end
		block:SetHeight(block.height + module.blockPadding);
			
		if ( not ObjectiveTracker_AddBlock(block) ) then
			-- there was no room to show the header and the block, bail
			block.used = false;
			return false;
		end

		block.posIndex = posIndex;
		block:Show();
		module:FreeUnusedLines(block);
			
		if ( treatAsInArea ) then
			if ( not isTrackedWorldQuest and questID == OBJECTIVE_TRACKER_UPDATE_ID ) then
				BonusObjectiveTracker_SetBlockState(block, "ENTERING");
			else
				BonusObjectiveTracker_SetBlockState(block, "PRESENT");
			end
		elseif ( existingTask ) then
			BonusObjectiveTracker_SetBlockState(block, "LEAVING");
		end
	end
	return true;
end

local function UpdateTrackedWorldQuests(module)
	for i = 1, GetNumWorldQuestWatches() do
		local watchedWorldQuestID = GetWorldQuestWatchInfo(i);
		if ( watchedWorldQuestID ) then
			if not AddBonusObjectiveQuest(module, watchedWorldQuestID, i, true) then
				break; -- No more room
			end
		end
	end
end

local function UpdateQuestBonusObjectives(module)
	module.Header.animateReason = OBJECTIVE_TRACKER_UPDATE_TASK_ADDED;
	local tasksTable = InternalGetTasksTable();
	for i = 1, #tasksTable do
		local questID = tasksTable[i];
		if ( module.ShowWorldQuests == QuestMapFrame_IsQuestWorldQuest(questID) and not IsWorldQuestWatched(questID) ) then
			if not AddBonusObjectiveQuest(module, questID, i + GetNumWorldQuestWatches()) then
				break; -- No more room
			end
		end
	end
	if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_TASK_ADDED or OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED ) then
		PlaySound("UI_Scenario_Stage_End");
	end
end

function BonusObjectiveTrackerModuleMixin:Update()
	-- ugh, cross-module dependance
	if ( SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction and self.contentsHeight == 0 ) then
		return;
	end

	if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_TASK_ADDED or OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED ) then
		if ( BANNER_BONUS_OBJECTIVE_ID == OBJECTIVE_TRACKER_UPDATE_ID ) then
			-- we just finished the banner for this, clear the data so the block displays
			BANNER_BONUS_OBJECTIVE_ID = nil;
		elseif ( not self:GetExistingBlock(OBJECTIVE_TRACKER_UPDATE_ID) and TopBannerManager_IsIdle() ) then
			-- if we don't already have a block for this and there's no other banner playing we should do the banner
			TopBannerManager_Show(ObjectiveTrackerBonusBannerFrame, OBJECTIVE_TRACKER_UPDATE_ID);
		end
	end

	self:BeginLayout();
	self.headerText = self.DefaultHeaderText;

	if ( self.ShowWorldQuests ) then
		UpdateTrackedWorldQuests(self);
	else
		UpdateScenarioBonusObjectives(self);
	end

	UpdateQuestBonusObjectives(self);

	if ( self.tooltipBlock ) then
		BonusObjectiveTracker_ShowRewardsTooltip(self.tooltipBlock);
	end
	
	if ( self.firstBlock ) then
		-- update module header text (certain bonus objectives can force this to change)
		self.Header.Text:SetText(self.headerText);
		-- shadow anim
		local shadowAnim = self.Header.ShadowAnim;
		if ( self.Header.animating and not shadowAnim:IsPlaying() ) then
			local distance = self.contentsAnimHeight - 8;
			shadowAnim.TransAnim:SetOffset(0, -distance);
			shadowAnim.TransAnim:SetDuration(distance * 0.33 / 50);
			shadowAnim:Play();
		end
	end

	self:EndLayout();
end

function BonusObjectiveTracker_SetBlockState(block, state, force)
	if ( block.state == state ) then
		return;
	end

	if ( state == "LEAVING" ) then
		-- only apply this state if block is PRESENT - let ENTERING anim finish
		if ( block.state == "PRESENT" ) then
			-- animate out
			block.AnimOut:Play();
			block.state = "LEAVING";
		end
	elseif ( state == "ENTERING" ) then
		if ( block.state == "LEAVING" ) then
			-- was leaving, just cancel the animation
			block.AnimOut:Stop();		
			block:SetAlpha(1);
			block.state = "PRESENT";
		elseif ( not block.state or block.state == "PRESENT" ) then
			-- animate in
			local maxStringWidth = 0;
			for _, line in pairs(block.lines) do
				maxStringWidth = max(maxStringWidth, line.Text:GetStringWidth());
			end
			block:SetAlpha(0);
			local anim = block.AnimIn;
			anim.TransOut:SetOffset((maxStringWidth + 17) * -1, 0);				
			anim.TransOut:SetEndDelay((block.module.contentsHeight - OBJECTIVE_TRACKER_HEADER_HEIGHT) * 0.33 / 50);					
			anim.TransIn:SetDuration(0.33 * (maxStringWidth + 17)/ 192);
			anim.TransIn:SetOffset((maxStringWidth + 17), 0); 
			anim:Play();
			block.state = "ENTERING";
		end
	elseif ( state == "PRESENT" ) then
		-- let ENTERING anim finish
		if ( block.state == "LEAVING" ) then
			-- was leaving, just cancel the animation
			block.AnimOut:Stop();
			block:SetAlpha(1);
			block.state = "PRESENT";
		elseif ( block.state == "ENTERING" and force ) then
			block.AnimIn:Stop();
			block:SetAlpha(1);
			block.state = "PRESENT";
		elseif ( not block.state ) then
			block:SetAlpha(1);
			block.state = "PRESENT";
		end
	elseif ( state == "FINISHED" ) then
		-- only apply this state if block is PRESENT
		if ( block.state == "PRESENT" ) then
			block.AnimOut:Play();
			block.state = "FINISHED";
		end
	end
end

-- *****************************************************************************************************
-- ***** PROGRESS BAR
-- *****************************************************************************************************
function BonusObjectiveTrackerModuleMixin:AddProgressBar(block, line, questID, finished)
	local progressBar = self.usedProgressBars[block] and self.usedProgressBars[block][line];
	if ( not progressBar ) then
		local numFreeProgressBars = #self.freeProgressBars;
		local parent = block.ScrollContents or block;
		if ( numFreeProgressBars > 0 ) then
			progressBar = self.freeProgressBars[numFreeProgressBars];
			tremove(self.freeProgressBars, numFreeProgressBars);
			progressBar:SetParent(parent);
			progressBar:Show();
		else
			progressBar = CreateFrame("Frame", nil, parent, "BonusTrackerProgressBarTemplate");
			progressBar.height = progressBar:GetHeight();
		end
		if ( not self.usedProgressBars[block] ) then
			self.usedProgressBars[block] = { };
		end
		self.usedProgressBars[block][line] = progressBar;
		progressBar:RegisterEvent("QUEST_LOG_UPDATE");
		progressBar:Show();
		-- initialize to the right values
		progressBar.questID = questID;
		if( not finished ) then
			BonusObjectiveTrackerProgressBar_SetValue( progressBar, GetQuestProgressBarPercent(questID) );
		end
		-- reward icon; try the first item
		local _, texture = GetQuestLogRewardInfo(1, questID);
		-- artifact xp
		local artifactXP, artifactCategory = GetQuestLogRewardArtifactXP(questID);
		if ( not texture and artifactXP > 0 ) then
			local name, icon = C_ArtifactUI.GetArtifactXPRewardTargetInfo(artifactCategory);
			texture = icon or "Interface\\Icons\\INV_Misc_QuestionMark";
		end
		-- currency
		if ( not texture and GetNumQuestLogRewardCurrencies(questID) > 0 ) then
			_, texture = GetQuestLogRewardCurrencyInfo(1, questID);
		end
		-- money?
		if ( not texture and GetQuestLogRewardMoney(questID) > 0 ) then
			texture = "Interface\\Icons\\inv_misc_coin_02";
		end
		-- xp
		if ( not texture and GetQuestLogRewardXP(questID) > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
			texture = "Interface\\Icons\\xp_icon";
		end
		if ( not texture ) then
			progressBar.Bar.Icon:Hide();
			progressBar.Bar.IconBG:Hide();
			progressBar.Bar.BarGlow:SetAtlas("bonusobjectives-bar-glow", true);
		else
			progressBar.Bar.Icon:SetTexture(texture);
			progressBar.Bar.Icon:Show();
			progressBar.Bar.IconBG:Show();
			progressBar.Bar.BarGlow:SetAtlas("bonusobjectives-bar-glow-ring", true);
		end
	end	
	-- anchor the status bar
	local anchor = block.currentLine or block.HeaderText;
	if ( anchor ) then
		progressBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -block.module.lineSpacing);
	else
		progressBar:SetPoint("TOPLEFT", 0, -block.module.lineSpacing);
	end

	if( finished ) then
		progressBar.finished = true;
		BonusObjectiveTrackerProgressBar_SetValue( progressBar, 100 );
	end
	
	progressBar.block = block;
	progressBar.questID = questID;	

	line.ProgressBar = progressBar;
	block.height = block.height + progressBar.height + block.module.lineSpacing;
	block.currentLine = progressBar;
	return progressBar;
end

function BonusObjectiveTrackerModuleMixin:FreeProgressBar(block, line)
	local progressBar = line.ProgressBar;
	if ( progressBar ) then
		self.usedProgressBars[block][line] = nil;
		tinsert(self.freeProgressBars, progressBar);
		progressBar:Hide(); 
		line.ProgressBar = nil;
		progressBar.finished = nil;
		progressBar.AnimValue = nil;
		progressBar:UnregisterEvent("QUEST_LOG_UPDATE");
		progressBar.Bar.AnimIn:Stop();
	end
end

function BonusObjectiveTrackerProgressBar_SetValue(self, percent)
	self.Bar:SetValue(percent);
	self.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
	self.AnimValue = percent;
end

function BonusObjectiveTrackerProgressBar_OnEvent(self)
	local percent = 100;
	if( not self.finished ) then
		percent = GetQuestProgressBarPercent(self.questID);
	end
	BonusObjectiveTrackerProgressBar_PlayFlareAnim(self, percent - self.AnimValue);
	BonusObjectiveTrackerProgressBar_SetValue(self, percent);
end

function BonusObjectiveTrackerProgressBar_PlayFlareAnim(progressBar, delta)
	if( progressBar.AnimValue >= 100 or delta == 0 ) then
		return;
	end
	
	local width = progressBar.Bar:GetWidth();
	local offset = width * (progressBar.AnimValue / 100) - 12;

	local prefix = "";
	if( delta < 10 ) then
		prefix = "Small";
	end

	local flare = progressBar[prefix.."Flare1"];
	if( flare.FlareAnim:IsPlaying() ) then
		flare = progressBar[prefix.."Flare2"];
		if( flare.FlareAnim:IsPlaying() ) then
			flare = nil;
		end
	end

	if ( flare ) then
		flare:SetPoint("LEFT", progressBar.Bar, "LEFT", offset, 0);
		flare.FlareAnim:Play();
	end
	
	local barFlare = progressBar["FullBarFlare1"];
	if( barFlare.FlareAnim:IsPlaying() ) then
		barFlare = progressBar["FullBarFlare2"];
		if( barFlare.FlareAnim:IsPlaying() ) then
			barFlare = nil;
		end
	end
	
	if ( barFlare ) then
		barFlare.FlareAnim:Play();
	end
end

-- *****************************************************************************************************
-- ***** BONUS OBJECTIVE BANNER
-- *****************************************************************************************************

function ObjectiveTrackerBonusBannerFrame_OnLoad(self)
	self.PlayBanner = ObjectiveTrackerBonusBannerFrame_PlayBanner;
	self.StopBanner = ObjectiveTrackerBonusBannerFrame_StopBanner;
end

function ObjectiveTrackerBonusBannerFrame_PlayBanner(self, questID)
	-- quest title
	local questTitle = GetQuestLogTitle(GetQuestLogIndexByID(questID));
	if ( not questTitle ) then
		return;
	end
	local colon = string.find(questTitle, ":");
	if ( colon ) then
		questTitle = string.sub(questTitle, colon + 1);
		-- remove leading spaces
		questTitle = gsub(questTitle, "^%s*", "");
	end
	self.Title:SetText(questTitle);
	self.TitleFlash:SetText(questTitle);
	local isWorldQuest = QuestMapFrame_IsQuestWorldQuest(questID);
	self.BonusLabel:SetText(isWorldQuest and WORLD_QUEST_BANNER or BONUS_OBJECTIVE_BANNER);
	-- offsets for anims
	local trackerFrame = ObjectiveTrackerFrame;
	local xOffset = trackerFrame:GetLeft() - self:GetRight();
	local height = 0;
	for i = 1, #trackerFrame.MODULES do
		height = height + (trackerFrame.MODULES[i].oldContentsHeight or trackerFrame.MODULES[i].contentsHeight or 0);
		if ( trackerFrame.MODULES[i] == QUEST_TRACKER_MODULE ) then
			break;
		end
	end
	local yOffset = trackerFrame:GetTop() - height - self:GetTop() + 64;
	self.Anim.BG1Translation:SetOffset(xOffset, yOffset);
	self.Anim.TitleTranslation:SetOffset(xOffset, yOffset);
	self.Anim.BonusLabelTranslation:SetOffset(xOffset, yOffset);
	self.Anim.IconTranslation:SetOffset(xOffset, yOffset);
	-- hide zone text as it's very likely to be up
	ZoneTextString:SetText("");
	SubZoneTextString:SetText("");
	-- show and play
	self:Show();
	self.Anim:Stop();
	self.Anim:Play();
	BANNER_BONUS_OBJECTIVE_ID = questID;
	-- timer to put the bonus objective in the tracker
	C_Timer.After(2.66, function() if BANNER_BONUS_OBJECTIVE_ID == questID then ObjectiveTracker_Update(isWorldQuest and OBJECTIVE_TRACKER_UPDATE_WORLD_QUEST_ADDED or OBJECTIVE_TRACKER_UPDATE_TASK_ADDED, BANNER_BONUS_OBJECTIVE_ID); end end);
end

function ObjectiveTrackerBonusBannerFrame_StopBanner(self)
	self.Anim:Stop();
	self:Hide();
end

function ObjectiveTrackerBonusBannerFrame_OnAnimFinished()
	TopBannerManager_BannerFinished();
end