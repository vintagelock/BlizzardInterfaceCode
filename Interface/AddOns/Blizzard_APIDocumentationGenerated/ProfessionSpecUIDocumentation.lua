local ProfessionSpecUI =
{
	Name = "ProfessionSpecUI",
	Type = "System",
	Namespace = "C_ProfSpecs",

	Functions =
	{
		{
			Name = "CanRefundPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "canRefund", Type = "bool", Nilable = false },
			},
		},
		{
			Name = "CanUnlockTab",
			Type = "Function",

			Arguments =
			{
				{ Name = "tabTreeID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "canUnlock", Type = "bool", Nilable = false },
			},
		},
		{
			Name = "GetChildrenForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "childIDs", Type = "table", InnerType = "number", Nilable = false },
			},
		},
		{
			Name = "GetConfigIDForSkillLine",
			Type = "Function",

			Arguments =
			{
				{ Name = "skillLineID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "configID", Type = "number", Nilable = false },
			},
		},
		{
			Name = "GetDescriptionForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "description", Type = "string", Nilable = false },
			},
		},
		{
			Name = "GetDescriptionForPerk",
			Type = "Function",

			Arguments =
			{
				{ Name = "perkID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "description", Type = "string", Nilable = false },
			},
		},
		{
			Name = "GetEntryIDForPerk",
			Type = "Function",

			Arguments =
			{
				{ Name = "perkID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "entryID", Type = "number", Nilable = false },
			},
		},
		{
			Name = "GetPerksForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "perkIDs", Type = "table", InnerType = "number", Nilable = false },
			},
		},
		{
			Name = "GetRootPathForTab",
			Type = "Function",

			Arguments =
			{
				{ Name = "tabTreeID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "rootPathID", Type = "number", Nilable = true },
			},
		},
		{
			Name = "GetSourceTextForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "sourceText", Type = "string", Nilable = false },
			},
		},
		{
			Name = "GetSpecTabIDsForSkillLine",
			Type = "Function",

			Arguments =
			{
				{ Name = "skillLineID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "specTabIDs", Type = "table", InnerType = "number", Nilable = false },
			},
		},
		{
			Name = "GetSpendCurrencyForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "currencyID", Type = "number", Nilable = true },
			},
		},
		{
			Name = "GetSpendEntryForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "entryID", Type = "number", Nilable = false },
			},
		},
		{
			Name = "GetStateForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "state", Type = "ProfessionsSpecPathState", Nilable = false },
			},
		},
		{
			Name = "GetStateForTab",
			Type = "Function",

			Arguments =
			{
				{ Name = "tabTreeID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "tabInfo", Type = "ProfessionsSpecTabState", Nilable = false },
			},
		},
		{
			Name = "GetTabInfo",
			Type = "Function",

			Arguments =
			{
				{ Name = "tabTreeID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "tabInfo", Type = "ProfTabInfo", Nilable = true },
			},
		},
		{
			Name = "GetUnlockEntryForPath",
			Type = "Function",

			Arguments =
			{
				{ Name = "pathID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "entryID", Type = "number", Nilable = false },
			},
		},
		{
			Name = "GetUnlockRankForPerk",
			Type = "Function",

			Arguments =
			{
				{ Name = "perkID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "unlockRank", Type = "number", Nilable = true },
			},
		},
		{
			Name = "GetUnspentPointsForSkillLine",
			Type = "Function",

			Arguments =
			{
				{ Name = "skillLineID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "unspentPoints", Type = "number", Nilable = false },
			},
		},
		{
			Name = "PerkIsEarned",
			Type = "Function",

			Arguments =
			{
				{ Name = "perkID", Type = "number", Nilable = false },
				{ Name = "configID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "isEarned", Type = "bool", Nilable = false },
			},
		},
		{
			Name = "ShouldShowSpecForSkillLine",
			Type = "Function",

			Arguments =
			{
				{ Name = "skillLineID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "shouldShow", Type = "bool", Nilable = false },
			},
		},
		{
			Name = "SkillLineHasSpecialization",
			Type = "Function",

			Arguments =
			{
				{ Name = "skillLineID", Type = "number", Nilable = false },
			},

			Returns =
			{
				{ Name = "hasSpecialization", Type = "bool", Nilable = false },
			},
		},
	},

	Events =
	{
	},

	Tables =
	{
	},
};

APIDocumentation:AddDocumentationTable(ProfessionSpecUI);