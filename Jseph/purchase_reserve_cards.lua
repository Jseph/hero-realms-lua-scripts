require 'herorealms'
require 'decks'
require 'stdlib'
require 'stdcards'
require 'hardai'
require 'mediumai'
require 'easyai'

-- Buff that counts how many times the player's deck was shuffled (due to draw or otherwise)
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
            text = format("{0}<sprite name=\"gold\">, <sprite name=\"expend\">: Acquire {1} to top of deck.\n(-1<sprite name=\"gold\"> per turn)", { dynamicCost, getCardNameStringExpression(target) }),
        }),
        effect = addSlotToTarget(slot).apply(target)
            .seq(acquireForFreeTarget(CardLocEnum.ExtraReveal).apply(target))
            .seq(showTextTarget("<size=75%>Acquired reserve card</size>").apply(selectSource()))
            .seq(moveTarget(CardLocEnum.Deck).apply(selectLoc(loc(currentPid, extraRevealPloc)).take(1))),
        cost = combineCosts({ expendCost, goldCost(dynamicCost) }),
        check = selectLoc(loc(currentPid, reservePloc)).count().gte(index)
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

    return createSkillDef({
        id = "purchase_first_reserve_skill",
        name = "Purchase Reserve",
        cardTypeLabel = "Skill",
        types = { skillType },
        abilities = {
            create_purchase_ability(9, 1, slot),
            create_purchase_ability(11, 2, slot),
            create_purchase_ability(13, 3, slot),
            create_purchase_ability(15, 4, slot),
        },
        layout = mainLayout,
        -- Note: Capitolization matters here.  If this is not all lowercase the game
        -- crashes at startup for some reason.
        layoutPath = "art/t_taxation"
    })
end

function setupGame(g)
    --testing flags
    local add_all_reserve_cards_to_deck = true
    local all_card_defs = {}
    local class_list = { "fighter", "wizard", "cleric", "ranger", "thief", 
        "barbarian", "alchemist", "druid", "necromancer", "bard", "monk" }
    if add_all_reserve_cards_to_deck then
        for n, x in pairs(_G) do
            if type(x) == "function" and string.find(n, "carddef$") then
                local firstWord = string.split(n, "_")[1]
                table.insert(all_card_defs, x())
            end
        end
    end
    table.insert(all_card_defs, purchase_first_reserve_skill_def())
    registerCards(g, all_card_defs)

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