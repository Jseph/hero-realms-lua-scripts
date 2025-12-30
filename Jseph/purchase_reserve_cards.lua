require 'herorealms'
require 'decks'
require 'stdlib'
require 'stdcards'
require 'hardai'
require 'mediumai'
require 'easyai'

-- Buff that counts how many times the player's deck was shuffled (due to draw or otherwise)
function draw_shuffle_counter_def()
    local layout = createLayout({
        name = "Draw Shuffle Counter",
        art = "art/t_cunning_of_the_wolf",
        text = format("Shuffles: {0}", { getCounter("draw_shuffles") })
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
        id = "draw_shuffle_counter",
        name = "Draw Shuffle Counter",
        layout = layout,
        abilities = {
            createAbility({
                id = "draw_shuffle_counter_inc",
                trigger = deckShuffledTrigger,
                activations = multipleActivations,
                effect = incrementCounterEffect("draw_shuffles", const(1)).seq(showTextExpressionEffect(
                    format("Your deck has been shuffled {0} times.", { getCounter("draw_shuffles") })
                ))
            }),
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
            text = format("{0}<sprite name=\"gold\">, <sprite name=\"expend\">: Move {1} to your hand.\n(-1<sprite name=\"gold\"> per turn)", { dynamicCost, getCardNameStringExpression(target) }),
        }),
        effect = addSlotToTarget(slot).apply(target)
            .seq(moveTarget(currentHandLoc).apply(target)),
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
        layoutPath = "avatars/profit"
    })
end

function setupGame(g)
    registerCards(g, {
		purchase_first_reserve_skill_def()
	})
    standardSetup(g, {
        description = "Custom no heroes game",
        playerOrder = { plid1, plid2 },
        ai = ai.CreateKillSwitchAi(createAggressiveAI(),  createHardAi2()),
        timeoutAi = createTimeoutAi(),
        opponents = { { plid1, plid2 } },
        players = {
            {
                id = plid1,
                startDraw = 5,
                name = "Player 1",
                avatar="assassin",
                health = 50,
                cards = {
                    deck = {
                        { qty=10, card=fire_gem_carddef() },
                    },
                    reserve = {
                        { qty = 1, card = wizard_treasure_map_carddef() },
                        { qty = 1, card = ranger_parrot_carddef() },
                        { qty = 1, card = fire_gem_carddef() },
                        { qty = 1, card = gold_carddef() },
                    },
                    skills = {
                        purchase_first_reserve_skill_def()
                    },
                    buffs = {
                        drawCardsCountAtTurnEndDef(5),
                        discardCardsAtTurnStartDef(),
                        fatigueCount(40, 1, "FatigueP1"),
                        draw_shuffle_counter_def(),
                    }
                }
            },
            {
                id = plid2,
                startDraw = 5,
                name = "Player 2",
                avatar="assassin",
                health = 50,
                cards = {
                    deck = {
                        { qty=2, card=dagger_carddef() },
                        { qty=8, card=gold_carddef() },
                    },
                    buffs = {
                        drawCardsCountAtTurnEndDef(5),
                        discardCardsAtTurnStartDef(),
                        fatigueCount(40, 1, "FatigueP2")
                    }
                }
            }            
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