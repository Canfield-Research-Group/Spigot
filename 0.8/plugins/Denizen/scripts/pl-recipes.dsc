#== Code to manage custom recipies. This automatially unlocks and updates all
# - players with custom recipes. Just set the custom key (base level)
# - code intercepts reload and player joins so any recipie changes are updated on `exs reload` or a player joining
#   - pl_auto_discover:true
#


# - Update all players with new recipes
pl___recipe_refresh:
  type: world
  events:
    on script reload:
        - run pl__send_recipes_to_all

    on player joins:
        - run pl__send_recipes_to_player def:<player>

# - Send updated recipes to all players
pl__send_recipes_to_all:
  type: task
  debug: false
  script:
    - foreach <proc[get_all_players]> as:player:
        - if <[player]> != null and <[player].is_online>:
              - run pl__send_recipes_to_player def:<[player]>


pl__send_recipes_to_player:
  type: task
  definitions: player
  debug: false
  script:
    # Only online players can
    - define custom_recipes <list[]>

    # Filter on a custom key, that normally should ONLY apply to items but we will double check
    - foreach <util.scripts.filter_tag[<[filter_value].data_key[pl_auto_discover]||false>]> as:script:
        # Double check this is a valid recipe
        - if <[script].container_type||null> == item:
            # All recipes are placed into the 'denizen' namespace and so far I cannot find a way to eliminate this
            # Build script name with namespace
            # Recipe names are the keys NOT scripts, in theory we probably should sdan ALL keys
            #  TODO: scan all recipe slots for names
            - define recipe_name denizen:<[script].data_key[recipes.1.recipe_id]>
            - define custom_recipes:->:<[recipe_name]>

    # Send discovered recipes
    #- debug log "<red>Recipes: <[custom_recipes]>"
    - if <[custom_recipes].is_empty.not>:
        - foreach <server.online_players> as:player :
            - adjust <[player]> quietly_discover_recipe:<[custom_recipes]>
            - adjust <[player]> resend_discovered_recipes


