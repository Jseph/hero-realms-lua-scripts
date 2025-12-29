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

-- Skill: pay 1 gold to purchase the first card in your reserve
function purchase_first_reserve_skill_def()
    -- TODO implement this basic proof of concept skill.
end

function setupGame(g)
    registerCards(g, {
		--purchase_first_reserve_skill_def()
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
                startDraw = 1,
                name = "Player 1",
                avatar="assassin",
                health = 50,
                cards = {
                    deck = { -- orc deck still in progress
                        { qty=1, card=dagger_carddef() },
                        { qty=1, card=gold_carddef() },
                    },
                    reserve = {
                        { qty = 1, card = wizard_treasure_map_carddef() },
                        { qty = 1, card = ranger_parrot_carddef() },
                    },
                    skills = {
                        --purchase_first_reserve_skill_def()
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