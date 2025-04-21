# == Recipies for items to make things more flexible for users and helping
# encouraging exploration and optizing storage (Quartz recovery)
#
# See: pl-recipies.dcs for code that uses `pl_auto_discover: true` and auto unlocks player and player clients

# == Help: https://meta.denizenscript.com/Docs/Search/recipe%20id#item%20script%20containers

# - Elytra
er__elytra:
    type: item
    # Custom to enable auto-discover
    pl_auto_discover: true
    material: elytra
    display name: Elytra Crafted
    recipes:
        1:
            type: shaped
            recipe_id: er__elytra
            group: misc
            # empty spots use air (|air|) without spaces
            input:
            - feather|phantom_membrane|feather
            - glowstone_dust|quartz|glowstone_dust
            - feather|sugar_cane|feather

# - Nether Quartz from a block
#   - Rerverse a quatze block back to quartz just for full reversal and storage
er__quartz:
    type: item
    # Custom to enable auto-discover
    pl_auto_discover: true
    material: quartz
    display name: Nether Quartz
    recipes:
        1:
            type: shapeless
            recipe_id: er__quartz
            group: misc
            output_quantity: 4
            # Must be on ONE line, if multiple use '|' (liek a list)
            input: quartz_block
