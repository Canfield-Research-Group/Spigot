#== Recipies to reduce annoyances with enchanting table. 
# - Enchant recipies are level 1, requiring player to merge books in anvil (See Fair-XP)
# - Elantra is far to useful to gate behind a random generator
#
# - See: pl-recipies.dcs for code that uses `pl_auto_discover: true` and auto unlocks player and player clients


# == Help: https://meta.denizenscript.com/Docs/Search/recipe%20id#item%20script%20containers

# - Unbreaking I
er__unbreaking_book_i:
    type: item
    # Custom to enable auto-discover
    pl_auto_discover: true
    material: enchanted_book
    enchantments:
        - unbreaking:1
    display name: Book Unbreaking I
    recipes:
        1:
            type: shaped
            recipe_id: er__book_unbreaking_i
            group: combat
            input:
                - obsidian|writable_book|obsidian
                - emerald|iron_pickaxe|emerald
                - emerald|emerald|emerald


# - Protection I
er__protection_book_i:
    type: item
    # Custom to enable auto-discover
    pl_auto_discover: true
    material: enchanted_book
    enchantments:
        - protection:1
    display name: Book Protection I
    recipes:
        1:
            type: shaped
            recipe_id: er__book_protection_i
            group: combat
            input:
                - obsidian|writable_book|obsidian
                - emerald|iron_chestplate|emerald
                - emerald|emerald|emerald

# - Sharpness I
er__sharpness_book_i:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - sharpness:1
  display name: Sharpness I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_sharpness_i
      group: combat
      input:
        - quartz|writable_book|quartz
        - emerald|iron_sword|emerald
        - emerald|emerald|emerald

# - Silk Touch
er__silk_touch_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - silk_touch:1
  display name: Silk Touch Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_silk_touch
      group: combat
      input:
        - feather|writable_book|feather
        - emerald|iron_pickaxe|emerald
        - emerald|emerald|emerald


# - Thorns I
er__thorns_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - thorns:1
  display name: Thorns I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_thorns
      group: combat
      input:
        - cactus|writable_book|cactus
        - emerald|iron_chestplate|emerald
        - emerald|emerald|emerald


# - Effeciency I
er__efficiency_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - efficiency:1
  display name: Efficiency I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_efficiency
      group: combat
      input:
        - redstone|writable_book|redstone
        - emerald|iron_pickaxe|emerald
        - emerald|emerald|emerald

# - Fortune I
er__fortune_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - fortune:1
  display name: Fortune I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_fortune
      group: combat
      input:
        - lapis_lazuli|writable_book|lapis_lazuli
        - emerald|iron_pickaxe|emerald
        - emerald|emerald|emerald

# - Looting I
er__looting_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - looting:1
  display name: Looting I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_looting
      group: combat
      input:
        - lapis_lazuli|writable_book|lapis_lazuli
        - emerald|iron_sword|emerald
        - emerald|emerald|emerald

# - Looting I
er__looting_book:
  type: item
  pl_auto_discover: true
  material: enchanted_book
  enchantments:
    - looting:1
  display name: Looting I Book
  recipes:
    1:
      type: shaped
      recipe_id: er__book_looting
      group: combat
      input:
        - lapis_lazuli|writable_book|lapis_lazuli
        - emerald|iron_sword|emerald
        - emerald|emerald|emerald

