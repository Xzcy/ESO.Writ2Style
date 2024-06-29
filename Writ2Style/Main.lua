WritToStyle = {}
local WTS = WritToStyle
WTS.name = "Writ2Style"

WTS.WritNameTable = {}

WTS.Dault = {
  ["Patch"] = {},
  ["LastId"] = 1,
}
-- Start point
local function OnAddOnLoaded(eventCode, addonName)
  --When loaded
  if addonName ~= WTS.name then return end
	EVENT_MANAGER:UnregisterForEvent(WTS.name, EVENT_ADD_ON_LOADED)
  
  WTS.SV = ZO_SavedVars:NewAccountWide("W2S_Vars", 1, nil, WTS.Dault)
  WTS.DataMix()
  --Build MenuItem
  WTS.MenuItem()
end
--Tool function--
--Is it a writ with style info?
local function IsWrit(Name)
  if not WTS.WritNameTable[1] then 
    for i = 1, #WTS.WritId do
      WTS.WritNameTable[GetItemLinkName(WTS.WritId[i])] = true
    end
  end
  return WTS.WritNameTable[Name] or false
end
--Handle with ItemLink string
local function ItemLinkParser(Link, Num)
  --Link check
  if not string.gmatch(Link, "|H.*|h") then return nil end
  local Table = {}
  --Divide Link
  for word in string.gmatch(Link, "%d+") do
    table.insert(Table, tonumber(word))
  end
  if not Num then return Table end
  return Table[Num]
end
--The menu in inventory
function WTS.MenuItem()
  if not LibCustomMenu then return end
  local fun = function(Inventory, _, Link)
    if not Link then
      local Type = ZO_InventorySlot_GetType(Inventory)
      if Type == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT then
				Link = GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(Inventory))
			end
			if Type == SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING then
				Link = GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(Inventory))
      end
    end
    if not Link then Link = GetItemLink(ZO_Inventory_GetBagAndIndex(Inventory)) end
    local Name = GetItemLinkName(Link)
    if not IsWrit(Name) then return end --Check is writ?
    local Entries = {
        {
          label = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES1301),
          callback = function() WTS.ToChat(Link) end,
        },
        {
          label = "TTC",
          callback = function() WTS.ToTTC(Link) end,
        },
      }
    AddCustomSubMenuItem("|t20:20:esoui/art/icons/master_writ_alchemy.dds|t -> |t20:20:esoui/art/icons/quest_letter_002.dds|t", Entries)
    ShowMenu()
  end
  --Inventory
  LibCustomMenu:RegisterContextMenu(fun)
  --Right on Link
  local Old = ZO_LinkHandler_OnLinkMouseUp
  ZO_LinkHandler_OnLinkMouseUp = function(Link, Button, Control)
    local Result = Old(Link, Button, Control)
    if Button == MOUSE_BUTTON_INDEX_RIGHT then
      fun(nil, nil, Link)
    end
    return Result
  end
end

--For public use
function Writ2StyleByLink(Link, Both)
  local ItemType = ItemLinkParser(Link, 8)
  local StyleId = ItemLinkParser(Link, 13)
  --Check again
  if not StyleId or not ItemType or ItemType*StyleId == 0 then return nil end
  local Index = WTS.TypeToType[ItemType]
  --Database Mode
  if WTS.Data[StyleId] then
    local chapter = WTS.Data[StyleId][Index]
    local book = WTS.Data[StyleId][15]
    if both then
      return chapter, book
    else
      return chapter or book
    end
  end
  --No data, try search for en/zh, prompt for others
  if GetCVar("language.2") ~= "en" and GetCVar("language.2") ~= "zh" then 
    d("Writ2Style: The data missed, plz wait for update.")
  end
  --Start search
  local StyleName = GetItemStyleName(StyleId)
  local Target = GetItemLinkName(WTS.ModelStyle[Index]):gsub(".*105", ""):gsub(GetItemStyleName(123), StyleName)
  --Start from the id of style material to speed up 
  local StartPoint = GetItemLinkItemId(GetItemStyleMaterialLink(StyleId)) 
  
  local chapter
  local book
  local Try = {
    {StartPoint -  1000, StartPoint + 1000},
    {WTS.Data["LastId"] or 1, 400000},
  }
  --To speed up, make it local function
  local F1 = string.format
  local F2 = GetItemLinkItemType
  local F3 = string.find
  local F4 = GetItemLinkName
  --To find both
  if Both then 
    for t = 1, #Try do
      for i = Try[t][1], Try[t][2] do
        local Link = F1("|H0:item:%d:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i)
        local Type, SubType = F2(Link)
        if not chapter and Type == 8 and SubType == 61 then
          if F3(F4(Link), Target) then
            chapter = Link
          end
        end
        if not book and Type == 8 and SubType == 60 then
          if F3(F4(Link), StyleName) then
            book = Link
          end
        end
        if chapter and book then break end
      end
      return chapter, book
    end
  end
  --To find chapter first
  for t = 1, #Try do
    for i = Try[t][1], Try[t][2] do
      local Link = F1("|H0:item:%d:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i)
      local Type, SubType = F2(Link)
      if Type == 8 and SubType == 61 then
        if F3(F4(Link), Target) then
          chapter = Link
          break
        end
      end
      if not book and Type == 8 and SubType == 60 then
        if F3(F4(Link), StyleName) then
          book = Link
        end
      end
    end
    if chapter then break end
  end
  return chapter or book
end
--/script WritToStyle.CreatDataBase(1)
--The function for creating database
function WTS.CreatDataBase(StartPoint)
  local Pattern = {}
  local StyleName = {}
  --Something like this ": 【1】 Halemts", for matching later
  for i = 1, 14 do
    Pattern[i] = GetItemLinkName(WTS.ModelStyle[i]):gsub(".*105", ""):gsub(GetItemStyleName(123), "【1】")
  end
  Pattern[15] = GetItemLinkName(WTS.ModelStyle[15]):gsub(".*16", ""):gsub(GetItemStyleName(28), "【1】")
  --[StyleName] = StyleId
  for i = 1, 1000 do
    local Name = GetItemStyleName(i)
    if Name ~= "" and GetItemStyleMaterialLink(i) ~= "" then
      StyleName[Name] = i
      WTS.SV[i] = {}
      WTS.SV[i]["Info"] = Name
      WTS.SV["Summary"] = {}
      table.insert(WTS.SV["Summary"], Name)
    end
  end
  --Speed up local function
  local F1 = string.format
  local F2 = GetItemLinkItemType
  local F3 = string.find
  local F4 = string.gsub
  local F5 = GetItemLinkName
  --Search
  WTS.SV["Version"] = GetESOVersionString()
  for i = math.max(WTS.SV["LastId"] - 10000, 1), 400000 do
    local Link = F1("|H0:item:%d:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i)
    local Type, SubType = F2(Link)
    --Chapter or book type, but sometimes it's reversed by mistake
    if Type == 8 and (SubType == 60 or SubType == 61) then 
      local Target = F5(Link)
      if F3(Target, "Crown") then --Abandon Crown style item
      else
        Target = F4(Target, ".*%d+", "") --Target:gsub(".*%d+", "")
        local Index = 0
        for a = 1, 15 do --What kind of equip the chapter hold
          if F3(Target, F4(Pattern[a], "【1】", ".+")) then --Pattern[a]:gsub("【1】", ".+")
            Index = a
            break
          end
        end
        if Index == 0 then
          d(Link) --The Item with wrong format, need to be patched.
          WTS.SV.Patch[Link] = {0, 0, F5(Link)}
        else
          for Style, StyleId in pairs(StyleName) do --Which Style
            if Target == F4(Pattern[Index], "【1】", Style) then --Pattern[Index]:gsub("【1】", Style)
                WTS.SV[StyleId][Index] = Link
                WTS.SV["LastId"] = i
            end
          end
        end
      end
    end
  end
end

--/script d(WritToStyle.FindByName(""))
--Search for everything
function WTS.FindByName(String)
  local F1 = string.format
  local F2 = GetItemLinkName
  for i = 1, 400000 do
    local Link = F1("|H0:item:%d:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i)
    if string.find(F2(Link), String) then
      d(Link)
    end
  end
end

--To chat window
function WTS.ToChat(Link)
  local TargetLink = Writ2StyleByLink(Link)
  d(TargetLink)
  StartChatInput(GetItemLinkName(TargetLink):gsub("%^.+", ""))
end

--/script WritToStyle.TOTTC("|H1:item:121532:6:1:0:0:0:28:194:5:696:12:107:0:0:0:0:0:0:0:0:998400|h|h")
--To TTC Website
local UrlBase= "https://【1】.tamrieltradecentre.com/pc/Trade/SearchResult?ItemNamePattern=【2】&lang=【3】"
function WTS.ToTTC(Link)
  local UrlName = GetItemLinkName(Writ2StyleByLink(Link)):gsub("%^.+", "") --For some language, "^xx" will be added
  local UrlServer = ""
  if string.find(GetWorldName(), "EU ") then 
    UrlServer = "eu"
  else
    UrlServer = "us"
  end
  local UrlLang = ""
  if GetCVar("language.2") == "en" then UrlLang = "en-US" end
  if GetCVar("language.2") == "zh" then UrlLang = "zh-CN" end
  if GetCVar("language.2") == "de" then UrlLang = "de-DE" end
  if GetCVar("language.2") == "fr" then UrlLang = "fr-FR" end
  if GetCVar("language.2") == "ru" then UrlLang = "ru-RU" end
  if GetCVar("language.2") == "es" then UrlLang = "es-ES" end
  if GetCVar("language.2") == "jp" then UrlLang = "ja-JP" end
  
  local Url = UrlBase:gsub("【1】", UrlServer):gsub("【2】", UrlName):gsub("【3】", UrlLang)
  RequestOpenUnsafeURL(Url)
end

--Data for search
WTS.WritId = { --To get exact name strings of writ item
  "|H0:item:119563:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Black
  "|H0:item:119694:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Cloth
  "|H0:item:121530:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", -- Wood
}

WTS.ModelStyle = {
  "|H1:item:176065:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Helmets
  "|H1:item:176069:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Shoulders
  "|H1:item:176062:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Chests
  "|H1:item:176064:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Gloves
  "|H1:item:176059:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Belts
  "|H1:item:176066:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Legs
  "|H1:item:176060:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Boots
  "|H1:item:176058:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Axes
  "|H1:item:176067:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Maces
  "|H1:item:176063:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Daggers
  "|H1:item:176071:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Swords
  "|H1:item:176068:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Shields
  "|H1:item:176061:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Bows
  "|H1:item:176070:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",  --Crafting Motif 105: Crimson Oath Staves
  "|H1:item:64669:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",   --Crafting Motif 16: Glass Style
}

WTS.TypeToType = {
  --Helmets
  [17] = 1, [26] = 1, [35] = 1, [44] = 1,
  --Shoulders
  [20] = 2, [29] = 2, [38] = 2, [47] = 2,
  --Chests
  [19] = 3, [28] = 3, [37] = 3, [46] = 3,
  --Gloves
  [25] = 4, [34] = 4, [43] = 4, [52] = 4,
  --Belts
  [21] = 5, [30] = 5, [39] = 5, [48] = 5,
  --Legs
  [22] = 6, [31] = 6, [40] = 6, [49] = 6,
  --Boots
  [23] = 7, [32] = 7, [41] = 7, [50] = 7,
  --Axes
  [53] = 8, [68] = 8,
  --Maces
  [56] = 9, [69] = 9,
  --Daggers
  [62] = 10,
  --Swords
  [59] = 11, [67] = 11,
  --Shields
  [65] = 12,
  --Bows
  [70] = 13,
  --Staves
  [71] = 14, [72] = 14, [73] = 14, [74] = 14,
}

--Start Here
EVENT_MANAGER:RegisterForEvent(WTS.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)