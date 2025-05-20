# Universal Configuation file for Paradise Labs scripts

pl_config_loader_events:
  type: world
  events:
    on server start:
        - run pl__load_config
    on script reload:
        - run pl__load_config


pl__load_config:
  type: task
  script:
  # Always reload this data, it is GOLDEN. If changes are allowed do so via commands or just edit file
  - yaml id:pl__config load:data/pl-config.yaml


# Returns configuraton located at path, if none return NULL but do NOT toss a warning
pl__config:
  type: procedure
  debug: false
  definitions: path
  script:
    - determine <yaml[pl__config].read[<[path]>]||null>
