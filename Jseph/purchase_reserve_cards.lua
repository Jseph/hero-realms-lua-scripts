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
    {"cleric_ship_s_bell", 4},
    {"cleric_imperial_sailor", 3}, -- This is apparently the old name of the card
    {"cleric_sacred_censer", 4},
    {"cleric_holy_water", 4},
    {"cleric_morningstar", 7},
    {"cleric_enduring_follower", 6},
    {"cleric_motes_of_light", 5},
    {"cleric_benediction_beads", 7},
    {"fighter_cutlass", 3},
    {"fighter_bottle_of_rum", 3},
    {"fighter_chain", 6},
    {"fighter_javelin", 3},
    {"fighter_taunting_talisman", 4},
    {"fighter_ruinic_throwing_axe", 4}, -- The card name just says "Throwing Axe." I'm guessing that's a mistake in the card name.
    {"fighter_iron_shield", 5},
    {"fighter_dazzling_ruby", 5},
    {"fighter_ruby_glaive", 5},
    {"ranger_spyglass", 3},
    {"ranger_parrot", 4},
    {"ranger_veiled_trap", 3},
    {"ranger_death_arrow", 4},
    {"ranger_hawk_pet", 3},
    {"ranger_gold_tipped_arrow", 6},
    {"ranger_trick_arrow", 3},
    {"ranger_stalking_bow", 6},
    {"thief_trick_dice", 4},
    {"thief_hook", 4},
    {"thief_kunai", 4},
    {"thief_blinding_powder", 6},
    {"thief_lockpick", 6},
    {"thief_ruby_encrusted_blade", 4},
    {"thief_parrying_dagger", 7},
    {"thief_lucky_knife", 6},
    {"wizard_ship_in_a_bottle", 4},
    {"wizard_treasure_map", 5},
    {"wizard_prestidigitation_charm", 5},
    {"wizard_clock_of_ages", 5},
    {"wizard_wand_of_wanting", 6},
    {"wizard_combust", 7},
    {"wizard_magic_scroll", 5},
    {"wizard_adept_s_components", 7},
    {"barbarian_ring_of_rage", 3},
    {"barbarian_earthshaker", 3},
    {"barbarian_caltrops", 3},
    {"barbarian_seething_spear", 4},
    {"barbarian_whip", 3},
    {"barbarian_double_bladed_hand_axe", 5},
    {"barbarian_net_of_thorns", 3},
    {"barbarian_pillage", 7},
    {"alchemist_fireworks", 4},
    {"alchemist_recalibration_crystal", 4},
    {"alchemist_kaleidoscope", 4},
    {"alchemist_vial_of_acid", 3},
    {"alchemist_recipe_book", 7},
    {"alchemist_rainbow_potion", 5},
    {"alchemist_silver_scales", 4},
    {"alchemist_diamond", 8},
    {"druid_entangling_roots", 2},
    {"druid_panther_eye_ring", 3},
    {"druid_wisdom_of_the_woods", 4},
    {"druid_sunbird", 4},
    {"druid_reclaim_the_forest", 4},
    {"druid_hardy_hedgehog", 6},
    {"druid_great_stag", 5},
    {"druid_flying_squirrel", 6},
    {"necromancer_severing_scythe", 4},
    {"necromancer_stitcher_s_kit", 5},
    {"necromancer_preserved_heart", 4},
    {"necromancer_dread_cauldron", 3},
    {"necromancer_bag_of_bones", 5},
    {"necromancer_soul_cage", 5},
    {"necromancer_withered_wand", 4}, -- Named this way instead of withering_wand for some reason
    {"necromancer_company_of_corpses", 5},
    {"bard_musical_darts", 3},
    {"bard_songbook", 3},
    {"bard_muse_s_paper", 5},
    {"bard_music_box", 4},
    {"bard_whistling_rapier", 7},
    {"bard_enchanted_flute", 5},
    {"bard_tuning_fork", 5},
    {"bard_captivating_herald", 6},
    {"monk_amulet_of_resolve", 4},
    {"monk_horn_of_ascendance", 3},
    {"monk_dragon_staff", 4},
    {"monk_tranquil_wind", 4},
    {"monk_arm_bands_of_solemnity", 5},
    {"monk_void_s_eye", 4},
    {"monk_staff_of_the_phoenix", 5},
    {"monk_radiant_blossom", 4},
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
    local unpurchasedReserveCardsNotInReserve = selectTargets().where(
                isCardWithSlot("reserve_card_slot").And(
                    isCardWithSlot("purchased_reserve_card_slot").invert()
                )).exclude(selectLoc(loc(currentPid, myRevealPloc)))
                .exclude(selectLoc(loc(currentPid, reservePloc)))
    local moveBackToReserve = createCardEffectAbility({
        id = "move_back_to_reserve",
        effect = moveTarget(currentReserve).apply(unpurchasedReserveCardsNotInReserve),
        cost = noCost,
        trigger = locationChangedCardTrigger,
        check = const(1).eq(1),
        activations = multipleActivations,
        tags = {  }
    })

    local applyCostChangeEffect = nullEffect()
    for _, override in ipairs(cardCostOverrides) do
        applyCostChangeEffect = applyCostChangeEffect.seq(
            addSlotToTarget(createCostChangeSlot(-override[2], { endOfTurnExpiry }))
                .apply(selectLoc(currentReserve).where(isCardName(override[1])))
        )
    end
    
    return createBuffDef({
        id = "keep_cards_in_reserve",
        name = "Keep Cards in Reserve",
        layout = layout,
        abilities = {
            createAbility({
                id = "add_slot_to_reserve_cards",
                trigger = startOfTurnTrigger,
                activations = multipleActivations,
                effect = addSlotToTarget(reserveSlot).apply(selectLoc(currentReserve))
                    .seq(applyCostChangeEffect)
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
    local target = selectLoc(loc(ownerPid, reservePloc)).take(1)
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
        text = format("<sprite name=\"expend\">: Acquire reserve cards to hand.{0}", 
            { ifElseString(
                target.count().eq(const(0)), 
                "", 
                format("\nNext card: {0}\n({1} gold)", {getCardNameStringExpression(target), cardCost}))}),
    })
end

local function create_basic_acquire_ability(slot)
    local target = selectLoc(loc(currentPid, reservePloc)).take(5)
    return createAbility({
        id = "purchase_first_reserve_card",
        trigger = uiTrigger,
        promptType = showPrompt,
        activations = multipleActivations,
        layout = basic_acquire_ability_layout(),
        effect = moveTarget(loc(currentPid, myRevealPloc)).apply(target.reverse())
            .seq(ifElseEffect(
                selectLoc(loc(currentPid, myRevealPloc)).take(1).where(getCardCost().lte(getPlayerGold(ownerPid))).count().gte(const(1)),
                pushTargetedEffect({
                    desc = "Choose a card to purchase",
                    validTargets =  selectLoc(loc(currentPid, myRevealPloc)).take(1).where(getCardCost().lte(getPlayerGold(ownerPid))),
                    min = 0,
                    max = 1,
                    targetEffect = addSlotToTarget(slot).seq(acquireTarget(0, CardLocEnum.Hand))
                        .seq(showTextTarget("<size=75%>Acquired reserve card</size>").apply(selectSource()))
                        .seq(moveTarget(CardLocEnum.Reserve).apply(selectLoc(loc(currentPid, myRevealPloc)).reverse())),
                    tags = { }                        
                }),
            waitForClickEffect("No affordable cards.", "")
                .seq(moveTarget(CardLocEnum.Reserve).apply(selectLoc(loc(currentPid, myRevealPloc)).reverse()))
                .seq(prepareTarget().apply(selectSource()))
            )),
        cost = expendCost,
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
        description = "Purchase Reserve Cards: A balancing effort by Jseph, Userkaffe and Azgalor.",
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
