// KitchenJokes.swift
// Kitchen Inventory
//
// A library of 200 food & cooking dad jokes.
// Displayed randomly on the AI tab — one per visit.
// Pattern carried over from RubberJoints AI Coach.

import Foundation

struct KitchenJokes {
    static let jokes: [String] = [
        // ── Fridge & Storage ──────────────────────────────────
        "My fridge and I have a lot in common. We both have a light that comes on when you open up.",
        "I told my fridge it was running. It said 'I'm not going anywhere.'",
        "My freezer is where leftovers go to be forgotten.",
        "I opened the fridge and something waved at me. Time to clean.",
        "My pantry is organized by vibes, not alphabetically.",
        "I have a love-hate relationship with my fridge. I love food, it hates keeping it fresh.",
        "My freezer is basically a time capsule of good intentions.",
        "I asked my fridge for something healthy. It laughed and showed me cheese.",
        "The fridge light is the only light guiding my life choices at midnight.",
        "My pantry has three sections: snacks, more snacks, and ingredients I'll never use.",

        // ── Expiration & Freshness ────────────────────────────
        "I live my life one expiration date at a time.",
        "My yogurt expired. We had a good run.",
        "That milk isn't expired, it's just going through a sour phase.",
        "Expiration dates are just suggestions… said no one at the hospital.",
        "I checked the expiration date and it checked me right back.",
        "My leftovers have leftovers at this point.",
        "If it smells fine and looks fine, it's fine. That's science.",
        "My bread went from fresh to antique in three days.",
        "I found something in the back of the fridge. I think it found me first.",
        "That avocado went from 'not yet' to 'too late' in six minutes.",

        // ── Eggs ──────────────────────────────────────────────
        "I'm egg-static about this inventory app.",
        "I told an egg a joke. It cracked up.",
        "Eggs are egg-cellent at every meal. I'll see myself out.",
        "I dropped an egg. It was an accident over easy.",
        "Hard-boiled eggs have a tough exterior but a soft heart.",
        "My eggs keep telling yolks. I can't take them seriously.",
        "Scrambled eggs are just eggs having a bad hair day.",
        "An egg walked into a bar. The bartender said 'we don't serve breakfast.'",
        "I tried to write a joke about eggs but I kept scrambling it.",
        "Deviled eggs are just eggs that made bad life choices.",

        // ── Vegetables ────────────────────────────────────────
        "Lettuce be honest, I bought too many greens again.",
        "I told my salad a joke. It said 'that's corny.'",
        "Celery is 95% water and 100% disappointing.",
        "I asked the broccoli for advice. It said 'stalk about it.'",
        "My vegetables judge me from the crisper drawer.",
        "I bought kale once. It's still in my fridge. We don't talk about it.",
        "Peas are the introverts of the vegetable world.",
        "Corn has ears but never listens to my meal plans.",
        "My carrots said I need to see things more clearly.",
        "I told the potato it was a couch potato. It didn't move.",
        "Mushrooms are fun guys at every dinner party.",
        "The onion made me cry but I still came back for more.",
        "I tried to organize my peppers. It was a hot mess.",
        "Spinach: because Popeye can't be wrong about everything.",
        "My cauliflower is pretending to be rice again.",

        // ── Fruits ────────────────────────────────────────────
        "Bananas are ap-peeling but they bruise easily.",
        "I told the banana to split. It actually did.",
        "That orange isn't the only thing getting juiced around here.",
        "Lemons: when life gives them to you, check the expiration date first.",
        "I grape-ly appreciate a good fruit pun.",
        "My apple fell far from the fridge. Rolled under the couch.",
        "Berries are berry good at disappearing before I use them.",
        "A grape said nothing when I stepped on it. It just let out a little wine.",
        "I asked the melon to elope. It said 'we cantaloupe.'",
        "Pineapples are proof that punk rockers can be sweet.",

        // ── Dairy ─────────────────────────────────────────────
        "I'm not saying I eat too much cheese, but my fridge filed a complaint.",
        "Milk does a body good. Spoiled milk does a body no.",
        "Cheese is just milk that grew up and got cultured.",
        "I have a grate relationship with cheese.",
        "My butter half is always in the fridge.",
        "Yogurt is just milk with a college degree.",
        "I told my cheese a joke. It said 'that was gouda.'",
        "Swiss cheese has holes but it's still whole.",
        "Cream cheese is the duct tape of breakfast foods.",
        "I bought too much butter. I'm on a roll.",

        // ── Meat & Protein ────────────────────────────────────
        "I have a rare talent for overcooking steak.",
        "My chicken crossed the kitchen. I don't know why.",
        "I told the steak a joke. It was a rare medium well done.",
        "Bacon is the duct tape of the food world. It fixes everything.",
        "My ground beef has more drama than a soap opera.",
        "Turkey is just chicken in formal wear.",
        "I asked the fish if it was fresh. It didn't say a word.",
        "Sausages are the worst. They always fear the wurst.",
        "Tofu is proof that confidence is everything.",
        "My salmon is upstream of every other protein in the fridge.",

        // ── Bread & Baking ────────────────────────────────────
        "I knead bread in my life.",
        "My sourdough starter has more personality than most people I know.",
        "That bread is toast. Literally.",
        "I loaf bread puns. They're the yeast I can do.",
        "My baguette is the breadwinner of this kitchen.",
        "Whole wheat bread tries so hard to be healthy. Bless its grain.",
        "I told my dough to rise. It said 'I'm working on it.'",
        "Croissants are just bread that went to Paris.",
        "My bread maker and I are on a roll.",
        "Flatbread is just regular bread having a bad day.",

        // ── Cooking & Kitchen ─────────────────────────────────
        "I'm a whisk taker in the kitchen.",
        "My cooking is so good, the smoke alarm cheers me on.",
        "I don't need a recipe. I need a miracle.",
        "My spice rack is just paprika and 14 jars of mystery powder.",
        "I cook with wine. Sometimes I even put it in the food.",
        "My kitchen has two temperatures: off and burnt.",
        "I put the 'pro' in 'probably shouldn't be cooking.'",
        "My cutting board has seen things it can't unsee.",
        "I asked the pan if it was non-stick. It stuck around anyway.",
        "My oven has trust issues. It always needs preheating.",
        "Cooking is just aggressive meal prep.",
        "My blender and I have a smooth relationship.",
        "I season my food with love. And way too much garlic.",
        "My spatula flipped out when I said I was getting a new one.",
        "I don't measure ingredients. I pour and pray.",

        // ── Shopping & Groceries ──────────────────────────────
        "I went to the store for milk. Came back with everything but milk.",
        "My grocery list and my actual cart have never met.",
        "I bought organic. My wallet is still recovering.",
        "Grocery shopping without a list is an extreme sport.",
        "I impulse-bought seven avocados. This is my reality now.",
        "My shopping cart has a mind of its own. It always drifts to the snack aisle.",
        "I told myself 'just the essentials.' Came home with a pineapple.",
        "Coupons are just treasure maps for adults.",
        "I judge my life by how many grocery bags I can carry in one trip.",
        "Self-checkout is just a test of your patience and honesty.",

        // ── Leftovers & Meal Prep ─────────────────────────────
        "Leftovers are just yesterday's ambition meeting today's laziness.",
        "My meal prep lasted exactly one meal.",
        "Tuesday's dinner is just Monday's dinner in a different container.",
        "I label my leftovers. The labels are lies.",
        "Meal prep is just cooking with trust issues.",
        "That container in the back of the fridge? Don't open it. Just don't.",
        "Leftovers build character. Especially the mysterious ones.",
        "I reheated my food. The microwave judged me.",
        "My tupperware collection is missing every single matching lid.",
        "Leftovers are proof that optimism exists in the kitchen.",

        // ── Snacks & Sweets ───────────────────────────────────
        "I'm on a seafood diet. I see food and I eat it.",
        "Chocolate doesn't ask questions. Chocolate understands.",
        "My diet starts tomorrow. It's been starting tomorrow for years.",
        "Chips are just potatoes living their best life.",
        "I hide snacks from my family. I'm a professional.",
        "Ice cream fixes everything. That's not a joke, that's a fact.",
        "Cookies are just cake that didn't try hard enough.",
        "My snack drawer is more organized than my life.",
        "I told the donut it was sweet. It said 'I know, I'm filled with it.'",
        "Pretzels are just bread doing yoga.",

        // ── Condiments & Spices ───────────────────────────────
        "Ketchup waits for no one. Except when you shake the bottle.",
        "My mustard is cutting it. The ketchup is trying to catch up.",
        "Hot sauce is just confidence in a bottle.",
        "I have 12 half-empty bottles of ranch. This is fine.",
        "Soy sauce is proof that a little goes a long way.",
        "My spice cabinet is a graveyard of good intentions.",
        "Salt and pepper: the original dynamic duo.",
        "I bought sriracha. Now everything tastes like sriracha.",
        "Mayonnaise is the most controversial member of the fridge.",
        "My olive oil is extra virgin and extra expensive.",

        // ── Beverages ─────────────────────────────────────────
        "Coffee isn't a beverage, it's a survival mechanism.",
        "I drink coffee because adulting without it is impossible.",
        "Tea is just leaf soup and I'm fine with that.",
        "My orange juice has more pulp fiction than Tarantino.",
        "Water is the best drink. But have you tried not water?",
        "I bought sparkling water. It has a bubbly personality.",
        "My smoothie has more ingredients than a chemistry experiment.",
        "Energy drinks are just spicy anxiety water.",
        "I told my juice to concentrate. It tried its best.",
        "Almond milk: because almonds definitely have udders.",

        // ── Pasta & Grains ────────────────────────────────────
        "I'm pasta point of no return with these carbs.",
        "Life is full of pasta-bilities.",
        "My rice cooker is the most reliable thing in my kitchen.",
        "Spaghetti is just noodles that let their hair down.",
        "I told the pasta it was impasta. It didn't take it well.",
        "Quinoa is rice that went to college and won't stop talking about it.",
        "Ramen is a hug in a bowl. A salty, delicious hug.",
        "My mac and cheese recipe is top secret. It's from the box.",
        "Rice is nice but have you tried rice twice? Fried rice.",
        "Penne for your thoughts on dinner tonight.",

        // ── Kitchen Wisdom ────────────────────────────────────
        "A watched pot never boils, but an unwatched one always overflows.",
        "The secret ingredient is always cheese. Always.",
        "If you can't stand the heat, order takeout.",
        "Home cooking: because restaurants don't let you eat in pajamas.",
        "The kitchen is my happy place. The dishes are not.",
        "Behind every great cook is a significant pile of dishes.",
        "I meal plan like an adult and eat cereal for dinner like a rebel.",
        "Cooking for one is just a fancy way of saying 'all of this is mine.'",
        "The five-second rule is just natural selection for food.",
        "My kitchen is clean because I haven't cooked in three days.",

        // ── AI & Inventory Humor ──────────────────────────────
        "I let AI manage my kitchen. It's smarter than my last roommate.",
        "My inventory app knows my fridge better than I do.",
        "AI says my bananas expire tomorrow. The bananas disagree.",
        "I asked AI for a recipe. It used everything expiring today. Genius.",
        "My kitchen has artificial intelligence but natural chaos.",
        "The AI organized my pantry. I can't find anything now.",
        "I scan receipts so AI can judge my food choices.",
        "AI predicted I'd buy chips again. It was right.",
        "My inventory app has seen some things. Expired things.",
        "I asked the AI what to cook. It said 'order pizza.' Smart AI.",
    ]
}
