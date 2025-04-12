# ChatGPT tunning for Denizen

The following are lessons from using Denizen (2025-04) and are used to help tune the Chat GPT model with
hard earned advice.

Pay special attention to WARNINGS and FAIL indicators. These are examples that DO NOT work but are commonly suggested
by some AI systems and web pages. Avoid using or recomending these constructs and instead look for alternate solutions,
often nearby to the fail example.


## General tips

- All data is ultimately strings, and Denizen dynamically parses types like maps, lists, and locations.
Denizen does 'cache' these rather effeciently as some form of internal structure, but avoid lost of little changes as this causes
a lot of string <=> internal structure manipulation.
- Lists and maps in flags should be kept shallow; nesting incurs more parsing overhead.
- To improve performance, parse lists once per scope using `.as[list]`, `.as[map]`, etc. and reuse that variable. While modern denzien seems to
do this autoamtically it can be helpful documentation wise to use these.
  - Denizen does not automatically index or cache flag access — repeated parsing can be expensive. It's best to assign large flags to
 a local variable via `define` then use that
- It is often easier to parse things if a key path is built then used for `flag[key_path]` instead of dot-chained paths inside the `flag[]`
- Consider carefully your flag, or any, list/map structure to avoiding excessive decoding. A list/map is only decoded/cached at the level accessed
not recursively. So accesing '[world.item_name]' is a loop is far slower than `define my_list big_list[world]` then using that list to loop on
per item.
- When passing maps/lists to procedures, escaping is important; they should be safely stringified via escaped and unescaped
- as[list] is preferred over as_list in modern Denizen.
- Async tasks in Denizen are safe for CPU-only work — no world/block changes anbd often not even READ access. The Denizen module for VSCode
will usually warn you of this as will Denizen when running via debug ouput.
    - In most cases Async tasks SHOULD be avoided. They are quite risky and not worth it except for special cases (external access, file aprsing, etc.)


## Denizen is TEXT based

Unlike many languages Denizen syntax is PURE text replacement. So the definition of a list when passed is litteraly the string
representation of that list:
    - Given: `define my_list `<[1|3|7|11|13].as[list]>`
    - Used in: `define my_new_list <[my_list]>`
    - Is tokenized as: `define my_new_list "l@<[1|3|7|11|13].as[list]>"`
    - THEN evaluated

An object is also a string. It is not used a visiable (barrate or debug) element, it is really a string.
    - For example an item `define my_item i@arrow[quantity=13]` sets `my_item` to that literal string
    - And if copied to a new definition OR passed the actual string is passed

Often this is fine, but for lists and maps or other complex elements some critical nuances are important to consider

- A call to a procedure passing a LARGE list will NOT pass reference to that list, it buildds the string representation
and passes that. If there are 10,000 values that is what is passed. For that reason try to avoid HUGE lists and sometimes
it's better to inline processing code than pass it around a lot.
    - More criticall passing complex object, especially lists and maps, can break the `run` or `proc` processing. Both
    of those use '|' as a paramater separater, which can also appear in maps and will appear in lists. This just breaks
    everything. Use `encoded` and `decoded` to deal with that

Perhaps the hardest to debug is when a element contains items that themselves match the tokenizer characters. FOr example '<' and
'['. Since the text is inserted then tokenized this can lead to really challening bugs. Again the fix is to store complex
data as encoded and remember to decode it.

Tips to avoid tokenizer issues:
    - Use `encoded` and `decoded` to store complex strings, especially those containing '|<>[]'
    - Break work into mutiple definition lines. Sometimes it is not practical to try an do all the work inline. The performance
    hit for splitting the line to make things easier to work with is usually extreamly low.
    - Add `debug log "<red>Debug: <[some_def]>` messages can be really useful.

Note: Internally the Denizen btye codelike interpretor may well cache and manipulate data useing high performance
code (maps and lists) the user interaction is ALWAYS text.

## Inline Debugging

While the `debug: true` in procedure or task is extreamly helpful, it can general far too much noise to be useful. In those
case the old school `debug log` can be benficial. The debug log format will always display unless Denizen is running in NO DEBUG
mode (which is NOT the default but may be active on servers).
    - Since Denizen is text only lists/maps are shown just fine, if hard to read. Tip: Copy and paste into most AI systems
    that are Denizen trained to review the data.
    - When done just comment those lines out or ideally remove them

## Sending Maps/Lists to tasks and procedures

Denzien can get VERY confused when sending lists or maps to other functions. To do this safely use `escaped` and `unescaped`

    ```
    - <proc[do_something].context[<[my_map].escaped>]
    ...

    type: procuredure
    definitions: map_safe
    script:
        - define my_map [<map_safe>.unescaped]
    ```

## Spread operations over time

A handy way to spread out operations over time without using state is to use a location to determin a hash.
This only works with blocks/entities or other location elements.
The following creates a hash numeric value, that can the be checked with `mod` against a value to help spread processing
across multiple ticks without any state. While not perfect it works quite well

- tick_group = (x * 31 + y * 13 + z * 7) % N

Prime numbers are used which tends to help spread things out a bit more. If 'y' is not needed you can drop it.
The 'N' is the tick count. For example use '8' and this will spread the processing in a somewhat random way (unless players are
really focused on abusing things) across 8 ticks.



## Inventory changes quick

The `inventory` command cannot use add/take and most commands COPY the entire inevntory. WHile useful if building a new
inventory consider the following fpr performance whena pplicable. Note the default
inventories are player unless otherwise specified.
- `take <[test_item]> quantity:[<test_item].quantity> from:<[feeder_chest].inventory>`
    - matches are EXACT for item including quantity
    - if `quanitity:` is not specified only ONE item is moved
- `give <[test_item]> to:<[feeder_chest].inventory>`
    - No nuances, this will put the test_item.material.name and test_item.quanity into the target
    - Noet that 'test_item' can be a text name (arrrow) and quantity: can be specified seperately:
        - `give item:<[feeder_item_name]> quantity:13 to:<[target_chest].inventory>`


There are a number of important nuances for the `take` command that do NOT apply to GIVE

 - take item:<[test_item]> from:<[feeder_chest].inventory>
    - `test_item` should be an inventory object including a quantity. If reading item data from an existing inventory,
    especially from a slot, the item object will include quantity.
    - In this form the EXACT quantity (and NBT data) is matched for. So if item is an `arrow` with quanitty `13` and this
    form will ONLY match a slot container 13 arrows, not 12, not 1, not 14, but exactly 13. But (WARNING) the `take` will **only**
    take ONE item. This is an odd nuance in Denizen.
- take item:<[my_matieral_name]> quantity:<[my_quantity]> from:<[feeder_chest].inventory>
    - This form will again match the quanityt EXACTLY but will take the quanity specified instead of one. 
    - A common form of this command that does what most people think the first example would do is:
    `take item:<[test_item].material.name> quantity:<[test_item].quantity> from:<[feeder_chest].inventory>` assuming
    test item is a fully formed item object.
- Using take often involves other commands to excamine the inventory first. If done in the same tick operation
checking then taking will work fine.
- WARNING: There is no indication of failure. TO check for failure examine inventory before using take, then examine
afterwords to verify the take worked.

Note that some examples for take/give abbreviate 'quantity' to 'qty', that is NOT allowed in modern Denizen.
Also use the full word.

- Example error: `Error Message: 'qty' in a tag or command is deprecated: use 'quantity'. ... Enable debug on the script for more information`


## Using Adjust to chaneg attributes

The `adjust` command probably does not do what you think it does. May examples online are wrong and AI can often
infer a usage that is also incorrect.

- `- adjust <[some_entity]> custom_name:FUNNY`
    - The entity referenced by some_entity is modified. NOT the object itself, the `some_entity` definition remains UNCHANGED
- `- adjust def:some_entity custom_name:FUNNY`
    - This will update the actual 'some_entity' defined ealier
    ```denizen
    - define my_item i@arrow[quantity=12]
    - debug log "<red>Before: <[my_item]>"
        # Above should show i@arrow[quantity=12]
    - adjust def:<[my_item]> quantity:99`
        # above should show i@arrow[quantity=99]
    - debug log "<red>After: <[my_item]>"
    ```
- FAILS: `- adjust <[item]> quantity:12`
    - This does nothing since an item (i@arrows[quantity=2]) is an object but NOT a reference so changing quantity here changes, I suspect,
    some virtual element that has NOTHING to do with the `item` definition passed. THIS FAILS



## Item Building

To build an item object from scratch requires multiple steps to avoid
Denizen parser limitations. Namely, build the string THEN convert to
an item. The literal method is a single line but lacks flexibility. The final object
created will be a string (like all objects in Denizen) of the form: `i@apple[quantity=12]`

    - Literal string
        ```denizen
        - define test_item i@apple[quantity=24]
        - debug log "<red>TEST string: <[test_item]> with <[test_item].quantity>"
        ```
    - Build a string then convert it using `item[...]`
        ```denizen
        - define feeder_item apple
        - define feeder_quantity 12
        - define item_string <[feeder_item]>[quantity=<[feeder_quantity]>]
        - define test_item <item[<[item_string]>]>
        - debug log "<red>TEST string: <[test_item]> with <[test_item].quantity>"
        ```
    - Build a string and then convert it use more modern `.as[item]` syntax
        ```denizen
        - define feeder_item arrow
        - define feeder_quantity 13
        # NOTE: Due to parser issues we cannot really combine the building of the string and converting to item in one line
        - define test_item <[feeder_item]>[quantity=<[feeder_quantity]>]
        - define test_item <[test_item].as[item]>
        - debug log "<red>TEST as.item: <[test_item]> with <[test_item].quantity>"
        ```
    - FAILS: THis is older Denizen and poor advice even then. Do NOT use this as it
    fails. Instead favor one of the above
        - define test_item <i@%feeder_item%[quantity=%feeder_quantity%]>
