# Universal Configuation file for Paradise Labs scripts

pl_config_loader_events:
  type: world
  events:
    on server start:
      - ~run pl__load_config
    on script reload:
      - ~run pl__load_config


pl__load_config_id:
  type: procedure
  script:
    # - NOTE: Code waitng for post processing of this data (sucha s helpers) MUST use a
    # - hard coded value to properly wait. Example: _helpers_config_merge()
    - determine pl__config

pl__load_config:
  type: task
  script:
  # Always reload this data, it is GOLDEN. If changes are allowed do so via commands or just edit file
  - define id <proc[pl__load_config_id]>
  - yaml id:<[id]> load:data/pl-config.yaml


# Returns configuraton located at path, if none return 'null', this is a string NOT NULL internal value as I can find
# no way to return that. So caller needs to check per: `- if <proc[pl__config].......> == null:
#   This is extreamly annoying and a limitation in Denizen
pl__config:
  type: procedure
  debug: false
  definitions: path
  script:
    - determine <yaml[pl__config].read[<[path]>].if_null[null]>
