require 'herorealms'
require 'decks'
require 'stdlib'
require 'stdcards'
require 'hardai'
require 'mediumai'
require 'easyai'

--testing flags
local addAllClassCardsToDeck = false
local decreaseCostPerTurn = false
local debugStart = false

-- constants
local cardCostOverrides = {
    {"wizard_treasure_map", 2},
    {"ranger_parrot", 3}
}

function keep_cards_in_reserve_buf_def()
    local layout = createLayout({
        name = "Keep Cards in Reserve",
        art = "art/t_cunning_of_the_wolf",
        text = "Reserve cards must be purchased."
    })
    local currentReserve = loc(currentPid, reservePloc)
    local reserveSlot = createSlot({
        id = "reserve_card_slot",
        expiresArray = { neverExpiry },
    })
    local moveBackToReserve = createCardEffectAbility({
        id = "move_back_to_reserve",
        effect = moveTarget(currentReserve).apply(selectTargets().where(
                isCardWithSlot("reserve_card_slot").And(
                    isCardWithSlot("purchased_reserve_card_slot").invert()
                ))),
        cost = noCost,
        trigger = locationChangedCardTrigger,
        check = const(1).eq(1),
        activations = multipleActivations,
        tags = {  }
    })
    
    return createBuffDef({
        id = "keep_cards_in_reserve",
        name = "Keep Cards in Reserve",
        layout = layout,
        abilities = {
            createAbility({
                id = "add_slot_to_reserve_cards",
                trigger = autoTrigger,
                activations = singleActivation,
                effect = addSlotToTarget(reserveSlot).apply(selectLoc(currentReserve))
            }),
        },
        cardEffectAbilities = {
            moveBackToReserve,
        }
    })
end

-- Helper function to create purchase abilities for reserve cards
local function create_purchase_ability(baseCost, index, slot)
    local target = selectLoc(loc(currentPid, reservePloc)).take(index).reverse().take(1)
    local rawCost = const(baseCost).add(getTurnsPlayed(currentPid).negate())
    local dynamicCost = ifInt(rawCost.gte(const(0)), rawCost, const(0))
    return createAbility({
        id = "purchase_reserve_activate_" .. index,
        trigger = uiTrigger,
        promptType = showPrompt,
        layout = createLayout({
            name = "Purchase Reserve",
            art = "art/T_Taxation",
            text = format("{0}<sprite name=\"gold\">, <sprite name=\"expend\">: Acquire {1} to hand.\n(-1<sprite name=\"gold\"> per turn)", { dynamicCost, getCardNameStringExpression(target) }),
        }),
        effect = addSlotToTarget(slot).apply(target)
            .seq(acquireForFreeTarget(CardLocEnum.ExtraReveal).apply(target))
            .seq(showTextTarget("<size=75%>Acquired reserve card</size>").apply(selectSource()))
            .seq(moveTarget(CardLocEnum.Hand).apply(selectLoc(loc(currentPid, extraRevealPloc)).take(1))),
        cost = combineCosts({ expendCost, goldCost(dynamicCost) }),
        check = selectLoc(loc(currentPid, reservePloc)).count().gte(index)
    })
end

local function basic_acquire_ability_layout()
    local target = selectLoc(loc(currentPid, reservePloc)).take(1)
    local cardCost = const(4)
    for _, override in ipairs(cardCostOverrides) do
        cardCost = ifInt(
            target.where(isCardName(override[1])).count().eq(const(1)),
            const(override[2]), 
            cardCost)
    end
    return createLayout({
        name = "Purchase Reserve",
        art = "art/T_Taxation",
        text = format("<sprite name=\"gold_{0}\">, <sprite name=\"expend\">: Acquire {1} to hand.", 
            { cardCost, getCardNameStringExpression(target) }),
    })
end

local function create_basic_acquire_ability(slot)
    local target = selectLoc(loc(currentPid, reservePloc)).take(1)
    local cardCost = const(4)
    for _, override in ipairs(cardCostOverrides) do
        cardCost = ifInt(
            target.where(isCardName(override[1])).count().eq(const(1)),
            const(override[2]), 
            cardCost)
    end
    return createAbility({
        id = "purchase_first_reserve_card",
        trigger = uiTrigger,
        promptType = showPrompt,
        layout = basic_acquire_ability_layout(),
        effect = addSlotToTarget(slot).apply(target)
            .seq(acquireForFreeTarget(CardLocEnum.ExtraReveal).apply(target))
            .seq(showTextTarget("<size=75%>Acquired reserve card</size>").apply(selectSource()))
            .seq(moveTarget(CardLocEnum.Hand).apply(selectLoc(loc(currentPid, extraRevealPloc)).take(1))),
        cost = combineCosts({ expendCost, goldCost(cardCost) }),
        check = selectLoc(loc(currentPid, reservePloc)).count().gte(1)
    })
end

-- Skill: pay dynamic gold to purchase one of the first 4 cards in your reserve
function purchase_first_reserve_skill_def()
    local slot = createSlot({ id = "purchased_reserve_card_slot", expiresArray = { neverExpiry } })
    
    -- Initial layout for the skill itself
    local firstCard = selectLoc(loc(currentPid, reservePloc)).take(1)
    local rawCost = const(9).add(getTurnsPlayed(currentPid).negate())
    local dynamicCost = ifInt(rawCost.gte(const(0)), rawCost, const(0))
    local mainLayout = createLayout({
        name = "Purchase Reserve",
        art = "art/T_Taxation",
        text = "Acquire reserve card.\nCost: 8 gold + 2 gold per index - 1 gold per turn.",
    })
    local purchaseAbilities = {}
    if decreaseCostPerTurn then
        table.insert(purchaseAbilities, create_purchase_ability(9, 1, slot))
        table.insert(purchaseAbilities, create_purchase_ability(11, 2, slot))
        table.insert(purchaseAbilities, create_purchase_ability(13, 3, slot))
        table.insert(purchaseAbilities, create_purchase_ability(15, 4, slot))
    else
        mainLayout = basic_acquire_ability_layout()
        table.insert(purchaseAbilities, create_basic_acquire_ability(slot))
    end

    return createSkillDef({
        id = "purchase_first_reserve_skill",
        name = "Purchase Reserve",
        cardTypeLabel = "Skill",
        types = { skillType },
        abilities = purchaseAbilities,
        layout = mainLayout,
        -- Note: Capitolization matters here.  If this is not all lowercase the game
        -- crashes at startup for some reason.
        layoutPath = "art/t_taxation"
    })
end

function setupGame(g)
    local allCardDefs = {}
    local classList = { "fighter", "wizard", "cleric", "ranger", "thief", 
        "barbarian", "alchemist", "druid", "necromancer", "bard", "monk" }
    
    local function contains(t, val)
        for _, v in pairs(t) do
            if v == val then return true end
        end
        return false
    end

    if addAllClassCardsToDeck then
        for n, x in pairs(_G) do
            if type(x) == "function" and string.find(n, "carddef$") then
                local firstWord = string.match(n, "^([^_]+)_")
                if contains(classList, firstWord) then
                    table.insert(allCardDefs, x())
                end
            end
        end
    end
    local allToRegister = { purchase_first_reserve_skill_def() }
    for _, cardDef in ipairs(allCardDefs) do
        table.insert(allToRegister, cardDef)
    end
    registerCards(g, allToRegister)
    local p1Deck = {}
    if addAllClassCardsToDeck then
        for _, cardDef in ipairs(allCardDefs) do
            table.insert(p1Deck, { qty = 1, card = cardDef })
        end
    end
    local p1Reserve = {}
    local p1Hand = {}
    if debugStart then
        p1Reserve = {
            { qty = 1, card = wizard_treasure_map_carddef() },
            { qty = 1, card = ranger_parrot_carddef() },
        }
        p1Hand = { { qty = 5, card = fire_gem_carddef() }}
    end
    standardSetup(g, {
        description = "Knights of  Balance: A Community Game Balancing Effort.",
        playerOrder = { plid1, plid2 },
        ai = ai.CreateKillSwitchAi(createAggressiveAI(),  createHardAi2()),
        timeoutAi = createTimeoutAi(),
        opponents = { { plid1, plid2 } },
        players = {
            {
                id = plid1,
                startDraw = 3,
                init = {
                    fromEnv = plid1
                },
                cards = {
                    reserve = p1Reserve,
                    deck = p1Deck,
                    hand = p1Hand,
                    discard = {
                    },
                    skills = {
                        purchase_first_reserve_skill_def(),
                    },
                    buffs = {
                        drawCardsCountAtTurnEndDef(5),
                        discardCardsAtTurnStartDef(),
                        fatigueCount(40, 1, "FatigueP1"),
                        keep_cards_in_reserve_buf_def(),
                    }
                }
            },
            {
                id = plid2,
                startDraw = 5,
                init = {
                    fromEnv = plid2
                },
                cards = {
                    reserve = {
                        --{ qty = 1, card = wizard_treasure_map_carddef() }
                        --{ qty = 1, card = ranger_parrot_carddef() }
                    },
                    deck = {
                    },
                    hand = {
                        --{ qty = 5, card = fire_gem_carddef() },
                    },
                    discard = {
                    },
                    skills = {
                        purchase_first_reserve_skill_def(),
                    },
                    buffs = {
                        drawCardsCountAtTurnEndDef(5),
                        discardCardsAtTurnStartDef(),
                        fatigueCount(40, 1, "FatigueP2"),
                        keep_cards_in_reserve_buf_def(),
                    }
                }
            },            
        }
    })
end

function endGame(g)
end

function setupMeta(meta)
    meta.name = "purchase_reserve_cards"
    meta.minLevel = 0
    meta.maxLevel = 0
    meta.introbackground = ""
    meta.introheader = ""
    meta.introdescription = ""
    meta.path = "C:/Users/jseph/hero-realms-lua-scripts/hero-realms-lua-scripts/Jseph/purchase_reserve_cards.lua"
    meta.features = {
    }
end
