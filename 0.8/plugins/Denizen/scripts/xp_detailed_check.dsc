xp_detailed_command:
  type: command
  name: xptotal
  description: Shows your detailed experience info
  usage: /xptotal
  permission: xptotal.use
  script:
    #- define progress <player.experience>
    - define level <player.xp_level>
    - define percent_to_level <player.xp.div[100]>
    - define points_to_next <player.xp_to_next_level>
    # TIP: xp_total is LIFETIME total, we want current total
    - define total_points <player.calculate_xp.truncate>
    - define total_progress <[level].add[<[percent_to_level]>]>
    # This drops decimals if not present and it takes 3-4 lines of code to always show those, not needed at this time
    - define rounded <[total_progress].round_to[2]>

    #- narrate "PL: <[level]> -- <[total_progress]> -- <[rounded]> -- <[points_to_next]> -- <[percent_to_level]> -- <[total_points]>"
    - narrate "<green>Experience Level: <yellow><[rounded]> <gray>/ <green>Points: <aqua><[total_points]>"
