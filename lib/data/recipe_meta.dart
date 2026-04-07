// [OOP] 靜態資料：食譜分類/標籤/顯示用的輔助資訊。

//每道菜幾多人份
const Map<String, int> kRecipeServings = {
  'r1': 2, // Tomato & Egg Stir-fry
  'r2': 2, // Garlic Butter Shrimp
  'r3': 3, // Chicken Breast & Broccoli Stir-fry
  'r4': 3, // Steamed Clams with Garlic and Ginger
  'r5': 2, // Pan-Seared Salmon Steak with Asparagus
  'r6': 8, // Winter Melon Soup with Pork Ribs
  'r7': 6, // Roasted Lamb Rack with Potato
  'r8': 3, // Stir-fried Pork with Bell Pepper and Green Pea
  'r9': 2, // Pan-Seared Beef Steak with Grilled Zucchini
  'r10': 4, // Braised Chicken Leg with Potato and Carrot
  'r11': 4, // Baked Honey Garlic Chicken Wings
  'r12': 2, // Bitter Gourd Stir-fry with Egg
  'r13': 3, // Corn and Tomato Egg Drop Soup
  'r14': 3, // Stir-fried Eggplant with Pork
  'r15': 2, // Smashed Cucumber Salad
  'r16': 3, // Shiitake Mushroom and Chicken Soup
  'r17': 4, // Lotus Root and Pumpkin Pork Rib Soup
  'r18': 4, // White Radish Beef Stew
  'r19': 2, // Pan-Fried Golden Threadfin Bream
  'r20': 2, // Stir-fried Ridge Gourd with Shrimp and Egg
  'r21': 3, // Ginger and Scallion Crab
  'r22': 3, // Classic Egg Fried Rice
  'r23': 3, // Shrimp Fried Rice
  'r24': 3, // Chicken and Broccoli Fried Rice
};

//難度等級(1-5)
const Map<String, int> kRecipeDifficulty = {
  'r1': 1, // Tomato & Egg Stir-fry
  'r2': 2, // Garlic Butter Shrimp
  'r3': 2, // Chicken Breast & Broccoli Stir-fry
  'r4': 2, // Steamed Clams with Garlic and Ginger
  'r5': 3, // Pan-Seared Salmon Steak with Asparagus
  'r6': 1, // Winter Melon Soup with Pork Ribs
  'r7': 4, // Roasted Lamb Rack with Potato
  'r8': 2, // Stir-fried Pork with Bell Pepper and Green Pea
  'r9': 3, // Pan-Seared Beef Steak with Grilled Zucchini
  'r10': 2, // Braised Chicken Leg with Potato and Carrot
  'r11': 2, // Baked Honey Garlic Chicken Wings
  'r12': 1, // Bitter Gourd Stir-fry with Egg
  'r13': 1, // Corn and Tomato Egg Drop Soup
  'r14': 3, // Stir-fried Eggplant with Pork
  'r15': 1, // Smashed Cucumber Salad
  'r16': 1, // Shiitake Mushroom and Chicken Soup
  'r17': 2, // Lotus Root and Pumpkin Pork Rib Soup
  'r18': 3, // White Radish Beef Stew
  'r19': 3, // Pan-Fried Golden Threadfin Bream
  'r20': 2, // Stir-fried Ridge Gourd with Shrimp and Egg
  'r21': 4, // Ginger and Scallion Crab
  'r22': 1, // Classic Egg Fried Rice
  'r23': 2, // Shrimp Fried Rice
  'r24': 2, // Chicken and Broccoli Fried Rice
};

//主要烹調方法
const Map<String, String> kRecipeMethod = {
  'r1': 'Stir-fry', // Tomato & Egg Stir-fry
  'r2': 'Sear', // Garlic Butter Shrimp
  'r3': 'Stir-fry', // Chicken Breast & Broccoli Stir-fry
  'r4': 'Steam', // Steamed Clams with Garlic and Ginger
  'r5': 'Sear', // Pan-Seared Salmon Steak with Asparagus
  'r6': 'Simmer', // Winter Melon Soup with Pork Ribs
  'r7': 'Roast', // Roasted Lamb Rack with Potato
  'r8': 'Stir-fry', // Stir-fried Pork with Bell Pepper and Green Pea
  'r9': 'Sear', // Pan-Seared Beef Steak with Grilled Zucchini
  'r10': 'Braise', // Braised Chicken Leg with Potato and Carrot
  'r11': 'Bake', // Baked Honey Garlic Chicken Wings
  'r12': 'Stir-fry', // Bitter Gourd Stir-fry with Egg
  'r13': 'Simmer', // Corn and Tomato Egg Drop Soup
  'r14': 'Stir-fry', // Stir-fried Eggplant with Pork
  'r15': 'Tossed', // Smashed Cucumber Salad
  'r16': 'Simmer', // Shiitake Mushroom and Chicken Soup
  'r17': 'Simmer', // Lotus Root and Pumpkin Pork Rib Soup
  'r18': 'Braise', // White Radish Beef Stew
  'r19': 'Pan-fry', // Pan-Fried Golden Threadfin Bream
  'r20': 'Stir-fry', // Stir-fried Ridge Gourd with Shrimp and Egg
  'r21': 'Stir-fry', // Ginger and Scallion Crab
  'r22': 'Stir-fry', // Classic Egg Fried Rice
  'r23': 'Stir-fry', // Shrimp Fried Rice
  'r24': 'Stir-fry', // Chicken and Broccoli Fried Rice
};

/// tot需要器材：每個食譜「所有步驟」會用到嘅器材總表
/// - 值要同你 recipes_data.dart 的 requiredEquipment 用同一套字串（例如: 'stove' / 'pot' / 'oven'）
const Map<String, List<String>> kRecipeTotalEquipment = {
  'r1': ['stove'], // Tomato & Egg Stir-fry
  'r2': ['stove'], // Garlic Butter Shrimp
  'r3': ['stove'], // Chicken Breast & Broccoli Stir-fry
  'r4': ['stove'], // Steamed Clams with Garlic and Ginger
  'r5': ['stove'], // Pan-Seared Salmon Steak with Asparagus
  'r6': ['stove'], // Winter Melon Soup with Pork Ribs
  'r7': ['oven'], // Roasted Lamb Rack with Potato
  'r8': ['stove'], // Stir-fried Pork with Bell Pepper and Green Pea
  'r9': ['stove'], // Pan-Seared Beef Steak with Grilled Zucchini
  'r10': ['stove'], // Braised Chicken Leg with Potato and Carrot
  'r11': ['oven'], // Baked Honey Garlic Chicken Wings
  'r12': ['stove'], // Bitter Gourd Stir-fry with Egg
  'r13': ['stove'], // Corn and Tomato Egg Drop Soup
  'r14': ['stove'], // Stir-fried Eggplant with Pork
  'r15': [], // Smashed Cucumber Salad
  'r16': ['stove'], // Shiitake Mushroom and Chicken Soup
  'r17': ['stove'], // Lotus Root and Pumpkin Pork Rib Soup
  'r18': ['stove'], // White Radish Beef Stew
  'r19': ['stove'], // Pan-Fried Golden Threadfin Bream
  'r20': ['stove'], // Stir-fried Ridge Gourd with Shrimp and Egg
  'r21': ['stove'], // Ginger and Scallion Crab
  'r22': ['stove', 'electric'], // Classic Egg Fried Rice
  'r23': ['stove', 'electric'], // Shrimp Fried Rice
  'r24': ['stove', 'electric'], // Chicken and Broccoli Fried Rice
};

//賣點 好似和recipes_data.dart的taste一樣,但沒太大問題,到時在看看
const Map<String, List<String>> kSellingPoints = {
  'r1': ['Quick home-style', 'High-protein, low-cost', 'One-pan meal'],
  'r2': ['Garlicky & rich', 'Great with rice', 'Fast to cook'],
  'r3': ['High-protein', 'Colorful', 'Quick weeknight meal'],
  'r4': ['Fresh umami', 'Easy steaming', 'Light & clean'],
  'r5': ['Omega-3 rich', 'Elegant plating', 'Fast sear'],
  'r6': ['Fresh', 'Light', 'Savory'],
  'r7': ['Juicy', 'Crispy crust', 'Hearty'],
  'r8': ['Colorful', 'Quick stir-fry', 'Great with rice'],
  'r9': ['Restaurant-quality', 'Butter-basted', 'Impressive'],
  'r10': ['Comfort food', 'One-pot meal', 'Fall-off-bone'],
  'r11': ['Sticky sweet', 'Party favorite', 'Oven-easy'],
  'r12': ['Healthy bitter', 'Quick wok', 'High-vitamin'],
  'r13': ['Light & nourishing', 'Sweet corn', 'Silky egg ribbons'],
  'r14': ['Spicy & bold', 'Wok hei', 'Rice killer'],
  'r15': ['Refreshing', 'No-cook', 'Crunchy'],
  'r16': ['Nourishing', 'Mushroom umami', 'Gentle simmer'],
  'r17': ['Hearty', 'Multi-ingredient', 'Family-size'],
  'r18': ['Tender beef', 'Root vegetable', 'Warming stew'],
  'r19': ['Crispy skin', 'Whole-fish', 'Savory sauce'],
  'r20': ['Light & fresh', 'Quick wok', 'Seasonal gourd'],
  'r21': ['Wok-fragrant', 'Cantonese classic', 'Rich umami'],
  'r22': ['Quick & easy', 'Wok hei', 'Rice cooker'],
  'r23': ['Protein-rich', 'Wok hei', 'One-bowl meal'],
  'r24': ['High-protein', 'Colorful', 'Rice cooker'],
};

//更詳細版本步驟
const Map<String, List<String>> kStepsVerbose = {
  'r1': [
    'Wash tomatoes and cut each into 6–8 wedges.',
    'Crack eggs into a bowl, add a pinch of salt, beat until yolks and whites are fully combined.',
    'Mince garlic cloves.',
    'Heat wok over high heat, add 1 tbsp oil, swirl to coat.',
    'Pour in beaten eggs, stir-fry until 70% set with large curds, remove and set aside.',
    'Add remaining 1 tbsp oil to wok, sauté minced garlic until fragrant about 30 seconds.',
    'Add tomato wedges, stir-fry 2 minutes until softened and juicy.',
    'Season with salt and sugar, stir to combine.',
    'Return eggs to wok, gently fold together with tomatoes for 1 minute, plate and serve.',
  ],
  'r2': [
    'Peel and devein shrimp, rinse under cold water, pat dry with paper towels.',
    'Season shrimp with salt and pepper, toss to coat evenly.',
    'Mince garlic cloves finely, cut lemon into wedges.',
    'Heat frying pan over medium-high heat, add oil and swirl to coat.',
    'Add shrimp in a single layer, sear 2 minutes without moving until pink on bottom.',
    'Flip shrimp, add butter and minced garlic, cook 1–2 minutes while spooning melted butter over shrimp.',
    'Squeeze lemon juice over shrimp, toss briefly, transfer to plate and serve with lemon wedges.',
  ],
  'r3': [
    'Slice chicken breast thinly against the grain into bite-sized pieces.',
    'Marinate chicken with 1 tbsp soy sauce and cornstarch, mix well and set aside for 10 minutes.',
    'Cut broccoli into small florets, peel and slice carrot into thin rounds, cut celery into diagonal slices.',
    'Mince garlic and slice ginger.',
    'Bring a pot of water to boil, blanch broccoli, carrot and celery for 2 minutes until bright, drain and set aside.',
    'Heat wok over high heat, add 1 tbsp oil, stir-fry marinated chicken until just cooked through about 3 minutes, remove and set aside.',
    'Add remaining oil to wok, sauté garlic and ginger until fragrant about 30 seconds.',
    'Add blanched vegetables, stir-fry 1 minute on high heat.',
    'Return chicken to wok, add remaining soy sauce, oyster sauce and salt, toss everything together for 1 minute.',
    'Drizzle sesame oil, give a final toss, plate and serve immediately.',
  ],
  'r4': [
    'Soak clams in cold salted water for 30 minutes to purge sand, discard any that do not close when tapped.',
    'Rinse clams thoroughly under running water, scrub shells clean, drain.',
    'Mince garlic, slice ginger into thin strips, halve Thai chilies lengthwise and remove seeds if less heat desired.',
    'Heat wok over high heat, add oil, sauté garlic, ginger and Thai chili until fragrant about 30 seconds.',
    'Add clams to wok, toss quickly to coat with aromatics.',
    'Splash in Shaoxing wine, immediately cover with lid and steam for 3–5 minutes until all clams open.',
    'Remove lid, discard any clams that remain closed, drizzle light soy sauce and sesame oil.',
    'Give a final toss, transfer to serving bowl and serve immediately.',
  ],
  'r5': [
    'Pat salmon steaks dry with paper towels, season both sides generously with salt and pepper.',
    'Let seasoned salmon sit at room temperature for 10 minutes.',
    'Trim woody ends of asparagus, peel lower third if thick, mince garlic, cut lemon into wedges.',
    'Heat frying pan over medium-high heat, add 1 tbsp olive oil.',
    'Place salmon skin-side up in pan, sear 3-4 minutes without moving until golden crust forms.',
    'Flip salmon, add butter and garlic to pan, reduce heat to medium, cook 3 minutes while spooning butter over fish.',
    'Remove salmon to plate, let rest 3 minutes.',
    'In the same pan, add remaining olive oil, sauté asparagus over medium-high heat for 3–4 minutes until tender-crisp, season with salt.',
    'Plate salmon alongside asparagus, squeeze lemon over both, serve immediately.',
  ],
  'r6': [
    'Soak ribs in cold water for 1 hour to remove blood.',
    'Blanch ribs in boiling water for 1 minute, rinse clean.',
    'Add ribs, ginger, 9 cups water, boil then simmer 90 minutes.',
    'Prepare winter melon, cut into bite-size pieces.',
    'Skim fat, add winter melon and salt, simmer 15 minutes.',
    'Season with white pepper, add scallions/cilantro.',
    'Serve ribs with light soy sauce on side.',
  ],
  'r7': [
    'Bring lamb racks to room temperature for 1 hour before cooking.',
    'Preheat oven to 200°C (400°F).',
    'Score fat cap of lamb in a crisscross pattern with a sharp knife, being careful not to cut into the meat.',
    'Rub lamb racks generously with 1 tbsp olive oil, salt, pepper, rosemary and thyme on all sides.',
    'Peel and quarter potatoes, dice onion, lightly crush garlic cloves with the flat of a knife.',
    'Toss potatoes, onion and garlic with remaining olive oil, salt and pepper on a parchment-lined baking tray.',
    'Place potatoes in oven and roast for 15 minutes to get a head start.',
    'Wrap exposed lamb bones with foil to prevent charring.',
    'Place lamb racks fat-side up on top of potatoes, return to oven.',
    'Roast for 20–25 minutes for medium-rare (internal temp 55°C) or until desired doneness.',
    'Remove lamb from oven, tent loosely with foil and rest for 10 minutes.',
    'If potatoes not yet golden, return tray to oven for 5 more minutes while lamb rests.',
    'Slice lamb rack between bones into individual chops, serve alongside roasted potatoes.',
  ],
  'r8': [
    'Slice pork into thin strips against the grain, marinate with 1 tbsp soy sauce and cornstarch for 10 minutes.',
    'Deseed and cut bell peppers into strips, dice onion, mince garlic.',
    'If using frozen green peas, blanch in boiling water for 1 minute, drain; if fresh, set aside.',
    'Heat wok over high heat until smoking, add 1 tbsp oil.',
    'Stir-fry marinated pork strips for 2 minutes until just cooked, remove and set aside.',
    'Add remaining oil, sauté garlic and ginger until fragrant about 30 seconds.',
    'Add onion and bell peppers, stir-fry on high heat for 2 minutes until slightly charred but still crisp.',
    'Return pork to wok, add green peas, remaining soy sauce, oyster sauce and sugar, toss for 1 minute.',
    'Plate and serve immediately while vegetables are still crisp.',
  ],
  'r9': [
    'Remove steaks from fridge and let come to room temperature for 30 minutes.',
    'Pat steaks very dry with paper towels, season both sides generously with salt and pepper.',
    'Slice zucchini lengthwise into 1cm thick planks, brush with olive oil, season with salt and pepper.',
    'Lightly crush garlic cloves with the flat of a knife, leave whole.',
    'Heat a heavy frying pan over high heat until very hot, add 1 tbsp olive oil.',
    'Place steaks in pan, sear 3 minutes on first side without moving until deep brown crust forms.',
    'Flip steaks, add butter and crushed garlic to pan, tilt pan and baste steaks with foaming butter for 2 minutes.',
    'Remove steaks to a warm plate, tent loosely with foil and rest for 5–8 minutes.',
    'While steak rests, sear zucchini planks in same pan over medium-high heat, 2 minutes per side until grill marks appear.',
    'Slice steak against the grain if desired, plate alongside zucchini, spoon pan juices over top and serve.',
  ],
  'r10': [
    'Chop chicken legs through the bone into 3–4 pieces each, rinse and pat dry.',
    'Blanch chicken pieces in boiling water for 2 minutes to remove impurities, drain and rinse clean.',
    'Peel and cut potatoes into large chunks, peel and roll-cut carrot, dice onion.',
    'Heat wok over medium-high heat, add oil, fry chicken pieces skin-side down until golden brown about 3 minutes.',
    'Push chicken aside, add garlic, ginger and onion, stir-fry 1 minute until fragrant.',
    'Add soy sauce, dark soy sauce, oyster sauce, sugar and five-spice powder, stir to coat chicken evenly.',
    'Add enough hot water to just cover the chicken, bring to a boil, then reduce to a gentle simmer.',
    'Cover and simmer for 20 minutes until chicken is tender.',
    'Add potato and carrot pieces, cover and continue simmering for 15 minutes until vegetables are tender and sauce has reduced.',
    'Uncover, increase heat to medium-high to thicken sauce for 2 minutes if needed, then plate and serve.',
  ],
  'r11': [
    'Rinse chicken wings, pat thoroughly dry with paper towels, score each wing 2–3 times with a knife.',
    'Mince garlic and grate ginger, combine with soy sauce, honey and sesame oil in a bowl to make marinade.',
    'Reserve 3 tbsp marinade for glazing, pour rest over wings, toss to coat, cover and refrigerate for at least 1 hour.',
    'Preheat oven to 200°C (400°F), line a baking tray with foil and place a wire rack on top, brush rack with oil.',
    'Arrange marinated wings in a single layer on the rack, leaving space between each.',
    'Bake for 25 minutes on middle rack of oven.',
    'Remove tray, brush reserved marinade on wings, flip each wing.',
    'Return to oven and bake for another 20 minutes until wings are caramelized and cooked through (internal temp 75°C).',
    'Remove from oven, let rest 3 minutes, transfer to serving plate.',
  ],
  'r12': [
    'Halve bitter gourd lengthwise, scoop out seeds and white pith with a spoon.',
    'Slice bitter gourd into thin half-moons about 3mm thick.',
    'Sprinkle 0.5 tsp salt over slices, toss and let sit 10 minutes to draw out bitterness, then rinse and squeeze dry.',
    'Beat eggs with a pinch of salt in a bowl, mince garlic.',
    'Heat wok over high heat, add 1 tbsp oil, pour in beaten eggs, scramble into large soft curds, remove and set aside.',
    'Add remaining oil to wok, sauté garlic 30 seconds until fragrant.',
    'Add bitter gourd slices, stir-fry on high heat for 3 minutes until slightly softened but still has bite.',
    'Season with soy sauce and sugar, toss to distribute evenly.',
    'Return scrambled eggs to wok, fold gently with bitter gourd for 30 seconds, plate and serve.',
  ],
  'r13': [
    'Shuck corn and cut kernels off the cob by standing cob upright and slicing downward.',
    'Cut tomatoes into small wedges, beat eggs lightly in a bowl.',
    'Mix cornstarch with 2 tbsp cold water to make a slurry, set aside.',
    'Bring 4 cups of water to a boil in a pot over high heat.',
    'Add corn kernels, return to boil, then reduce to medium and simmer 5 minutes until corn is sweet.',
    'Add tomato wedges, simmer 3 minutes until tomatoes soften and release juice.',
    'Season with salt and white pepper, stir in cornstarch slurry, bring back to a gentle boil until slightly thickened.',
    'Turn off heat, slowly drizzle beaten egg in a thin stream while stirring gently in one direction to form ribbons.',
    'Drizzle sesame oil, ladle into bowls and serve immediately.',
  ],
  'r14': [
    'Roll-cut eggplants into bite-sized chunks, soak in salted water for 10 minutes to prevent browning, drain and squeeze dry.',
    'Mince pork into small pieces or use ground pork.',
    'Mince garlic and ginger, slice Thai chili into rings, mix cornstarch with 2 tbsp water for slurry.',
    'Heat wok over high heat, add 2 tbsp oil, fry eggplant pieces 3–4 minutes until softened and lightly golden, remove and drain.',
    'Add remaining oil to wok, stir-fry minced pork over high heat until crumbly and cooked through about 2 minutes.',
    'Add doubanjiang, garlic, ginger and Thai chili, stir-fry 30 seconds until oil turns red and fragrant.',
    'Return eggplant to wok, add soy sauce, sugar and vinegar, toss to combine.',
    'Add cornstarch slurry, stir until sauce thickens and coats eggplant evenly.',
    'Plate and serve immediately.',
  ],
  'r15': [
    'Wash cucumbers, trim ends, place flat on cutting board and smash firmly with the flat side of a knife until they crack open.',
    'Tear or cut smashed cucumbers into rough bite-sized pieces.',
    'Sprinkle salt over cucumber pieces, toss and let sit 10 minutes to draw out excess water, then drain.',
    'Mince garlic finely, slice Thai chili into thin rings.',
    'In a small bowl, whisk together soy sauce, vinegar, sesame oil, sugar and chili oil to make dressing.',
    'Tear iceberg lettuce leaves into pieces and lay on serving plate as a bed.',
    'Toss drained cucumber with garlic, chili and dressing, pile on top of lettuce and serve.',
  ],
  'r16': [
    'If using dried shiitake, soak in warm water for 30 minutes until fully softened, reserve soaking liquid; if fresh, clean and halve.',
    'Slice chicken breast thinly against the grain, marinate with Shaoxing wine and a pinch of salt for 10 minutes.',
    'Remove stems from soaked shiitake, halve or quarter depending on size.',
    'Bring 5 cups of water (or mix soaking liquid with water) to a boil with ginger slices in a pot.',
    'Add shiitake mushrooms, reduce heat to medium-low, simmer for 15 minutes to develop flavor.',
    'Add sliced chicken, gently stir to separate pieces, cook 3–4 minutes until chicken is just cooked through.',
    'Season with salt and white pepper, drizzle sesame oil.',
    'Ladle into bowls and serve immediately.',
  ],
  'r17': [
    'Chop pork ribs into 2-inch segments, soak in cold water for 30 minutes to remove blood.',
    'Blanch ribs in a pot of boiling water for 2 minutes, skim scum, drain ribs and rinse clean.',
    'Peel lotus root, cut into 1cm thick rounds; peel pumpkin, cut into large chunks; cut corn into 3–4 sections.',
    'In a large pot, add blanched ribs, lotus root, ginger slices and 8 cups of water, bring to a boil over high heat.',
    'Reduce heat to low, cover and simmer gently for 60 minutes until lotus root is tender and broth is milky.',
    'Skim any fat from the surface, add corn sections and pumpkin chunks.',
    'Continue simmering for 20 minutes until pumpkin is soft and corn is cooked.',
    'Season with salt and white pepper, stir gently.',
    'Ladle soup into bowls making sure each gets pork, lotus root, pumpkin and corn, serve hot.',
  ],
  'r18': [
    'Cut beef into 2cm cubes, soak in cold water for 20 minutes to remove blood, drain.',
    'Blanch beef cubes in boiling water for 2 minutes with a splash of Shaoxing wine, skim scum, drain and rinse clean.',
    'Peel white radish and carrot, cut into large rolling chunks; dice onion; slice ginger.',
    'Heat wok over medium-high heat, add oil, sear beef cubes on all sides until browned about 3 minutes.',
    'Add ginger, onion and five-spice powder, stir-fry until fragrant about 1 minute.',
    'Add soy sauce, dark soy sauce, sugar and remaining Shaoxing wine, stir to coat beef.',
    'Transfer to a deep pot, add enough hot water to cover beef by 2cm, bring to a boil.',
    'Reduce heat to low, cover and simmer gently for 60 minutes until beef is tender.',
    'Add white radish and carrot chunks, continue simmering covered for 25 minutes until radish is translucent and soft.',
    'Taste and adjust seasoning with salt if needed, ladle into bowls and serve hot.',
  ],
  'r19': [
    'Clean fish thoroughly, remove scales, gut and rinse cavity, pat completely dry inside and out with paper towels.',
    'Score fish with 3 diagonal cuts on each side about 1cm deep to help heat penetrate evenly.',
    'Rub fish inside and out with salt, stuff cavity with 2 slices of ginger, let sit 10 minutes.',
    'Slice remaining ginger into thin strips, mince garlic.',
    'Pat fish dry again, heat a flat-bottomed frying pan over medium heat, add oil and swirl to coat evenly.',
    'Carefully lay fish in pan, fry undisturbed for 4–5 minutes until bottom is golden and crispy.',
    'Gently flip fish with a spatula, fry the other side 4–5 minutes until equally golden.',
    'Push fish to one side, add ginger strips and garlic to pan, sauté 30 seconds until fragrant.',
    'Add light soy sauce, Shaoxing wine, sugar and 2 tbsp water, let sauce simmer around the fish for 2 minutes.',
    'Carefully transfer fish to serving plate, spoon sauce and aromatics over the top, serve immediately.',
  ],
  'r20': [
    'Peel ridge gourd skin, remove tough ridges, cut diagonally into 1cm thick slices.',
    'Peel and devein shrimp, rinse and pat dry, mince garlic and slice ginger.',
    'Beat eggs with a pinch of salt in a bowl.',
    'Heat wok over high heat, add 1 tbsp oil, pour in eggs and scramble into soft curds, remove and set aside.',
    'Add remaining oil to wok, sauté garlic and ginger until fragrant about 20 seconds.',
    'Add shrimp, stir-fry 1–2 minutes until they turn pink and curl, remove and set aside.',
    'Add ridge gourd slices to wok, stir-fry on high heat for 2 minutes, add 2 tbsp water, cover and steam 1 minute until just tender.',
    'Return shrimp and eggs to wok, season with salt and white pepper, toss everything together for 30 seconds.',
    'Drizzle sesame oil, give a final toss, plate and serve immediately.',
  ],
  'r21': [
    'Clean crabs thoroughly with a brush under running water, remove top shell, discard gills and innards, crack claws with the back of a knife.',
    'Cut each crab body into 4 pieces, dust cut surfaces lightly with cornstarch to seal in juices.',
    'Julienne ginger into thin strips, mince garlic, mix light soy sauce, oyster sauce, sugar, white pepper and 2 tbsp water in a bowl.',
    'Heat wok over high heat until smoking, add oil, carefully place crab pieces cut-side down, sear 2 minutes until shell turns red.',
    'Flip crab pieces, push to side, add ginger and garlic, stir-fry 30 seconds until very fragrant.',
    'Splash Shaoxing wine around the edge of wok, immediately pour in sauce mixture, toss to coat.',
    'Cover and cook for 5 minutes over medium heat until crab is fully cooked through.',
    'Uncover, increase heat to high, toss for 1 minute to reduce and thicken sauce.',
    'Drizzle sesame oil, transfer to serving plate, pour remaining sauce over crab and serve immediately.',
  ],
  'r22': [
    'Rinse rice under cold water until water runs clear, drain and add to rice cooker with water.',
    'Start rice cooker, cook rice until done about 20 minutes.',
    'Dice carrot into small cubes, dice onion finely, mince garlic.',
    'Beat eggs with a pinch of salt in a bowl.',
    'When rice is done, spread on a plate and let cool slightly for 5 minutes to reduce moisture.',
    'Heat wok over high heat until smoking, add 1 tbsp oil.',
    'Pour in beaten eggs, scramble into large curds just until set, remove and set aside.',
    'Add remaining oil to wok, sauté garlic and onion until fragrant about 30 seconds.',
    'Add diced carrot and green peas, stir-fry 1 minute until carrot is slightly softened.',
    'Add cooked rice, break up clumps with spatula, stir-fry on high heat for 2 minutes tossing constantly.',
    'Add soy sauce along the edge of wok, toss rice to coat evenly, season with salt and white pepper.',
    'Return scrambled eggs to wok, break into pieces, fold together with rice for 30 seconds.',
    'Drizzle sesame oil, give a final toss, plate and serve immediately.',
  ],
  'r23': [
    'Rinse rice under cold water until water runs clear, drain and add to rice cooker with water.',
    'Start rice cooker, cook rice until done about 20 minutes.',
    'Peel and devein shrimp, rinse under cold water, pat dry with paper towels, season with a pinch of salt.',
    'Dice carrot into small cubes, cut corn kernels off the cob, dice onion finely, mince garlic.',
    'Beat eggs with a pinch of salt in a bowl.',
    'When rice is done, spread on a plate and let cool slightly for 5 minutes.',
    'Heat wok over high heat, add 1 tbsp oil, sear shrimp 1 minute per side until pink, remove and set aside.',
    'Add beaten eggs to wok, scramble into curds, remove and set aside.',
    'Add remaining oil, sauté garlic and onion until fragrant about 30 seconds.',
    'Add diced carrot and corn kernels, stir-fry 1 minute on high heat.',
    'Add cooked rice, break up clumps, stir-fry 2 minutes tossing constantly on high heat.',
    'Add soy sauce along edge of wok, toss to coat, season with salt and white pepper.',
    'Return shrimp and scrambled eggs, fold together for 30 seconds, drizzle sesame oil, plate and serve.',
  ],
  'r24': [
    'Rinse rice under cold water until water runs clear, drain and add to rice cooker with water.',
    'Start rice cooker, cook rice until done about 20 minutes.',
    'Dice chicken breast into 1cm cubes, marinate with 1 tbsp soy sauce for 10 minutes.',
    'Cut broccoli into very small florets, dice onion finely, mince garlic, slice ginger.',
    'Beat eggs with a pinch of salt in a bowl.',
    'When rice is done, spread on a plate and let cool slightly for 5 minutes.',
    'Heat wok over high heat, add 1 tbsp oil, stir-fry chicken cubes 2 minutes until cooked through, remove and set aside.',
    'Pour in beaten eggs, scramble into large curds, remove and set aside.',
    'Add remaining oil, sauté garlic, ginger and onion until fragrant about 30 seconds.',
    'Add broccoli florets, stir-fry 1 minute on high heat until bright green.',
    'Add rice, break up clumps, stir-fry 2 minutes tossing constantly.',
    'Add remaining soy sauce and oyster sauce along edge of wok, toss to coat, season with salt and white pepper.',
    'Return chicken and eggs, fold together 30 seconds, drizzle sesame oil, plate and serve.',
  ],
};
