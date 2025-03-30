# Return all players online or off
get_all_players:
  type: procedure
  debug: false
  script:

  - define all_players <server.offline_players>
  - define all_players <[all_players].include[<server.online_players>]>
  - determine <[all_players]>
