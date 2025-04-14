# ChatGPT tunning for Denizen

The following are lessons from using Denizen (2025-04) and are used to help tune the Chat GPT model with
hard earned advice.

Pay special attention to WARNINGS and FAIL indicators. These are examples that DO NOT work but are commonly suggested
by some AI systems and web pages. Avoid using or recomending these constructs and instead look for alternate solutions,
often nearby to the fail example.


When recomending suggestions pay special attention the deprecation section for any command. If such a section is found
be sure to recomend or suggest using the modern version. For example the 'as_list' section specifies:

- Deprecated, use as[list]

In this case any use of `as_list` should recomend `.as[list]`.

Most object notation have a more modern `.as[object-type]`, see the 


Prompt: Favor any uploaded documents over existing data when offering advice or suggestions.

Credit: While most of this document was created by Robb@canfield.com, some sections were copied based on AI conversations,
cross checked and usually tested, then edited and formatted.

## Scaler oprations

To find scaler operations review the `ElementTag` documentation. This is where math and string operations reside.


## Utility Functions

To find special utility functions that are useful for common misc operations. Most of the time these return server/system
or common basic elements. They typically do not operate on script values. A very small example of the functions available:

- util.current_time_milli and other time operations
- util.current_tick
- util.list_numbers_to for a range of numbers
- util.pi and other constants
- And many more.



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

See also: Escaping System in Denizen documentation


### Parsing

Denizen parses each line (except comments) rerursively frrom innermost to outermost.

- find all <..> from deepest to outermost and evaluate, returning the results as text and inserted into the result.
- Each is resolved as parsed and the results inserted as TEXT
- Contrived Example Parsed: `define result <[my_data].get[3].if_null[<[feeder_chest].inventory>]>`
    - 1. Deepest '<...>' : `<[feeder_chest].inventory>`
    - 2. this is evaluted as and processed resulting in an invtory list. Note this happens ALWAYS
    - 3. The [my_data].get[3].if_null[-the-invetory-result-from-above]
        - And will return either the 3rd element from the [my_data] OR the reslt of the `.inventory`
    - Lessons learned: The operation will suffer all side effects of all nested <...> without
    regard to surrounding elements. So in this case '<[feeder_chest].inventory>` is performend always,
    at whatever performance cost or other side effects.

Another example:

- `define result <[my_data].get[3].if_null[list[]]>`
- This parse as a single operation  if the if_null returning a LITERAL 'list[]' not resolved since it is not wrapped in <...>
- FIX: `define result <[my_data].get[3].if_null[<list[]>]>` which WILL resolve to @li and use that if the get[3] is null.



## Inline Debugging

While the `debug: true` in procedure or task is extreamly helpful, it can general far too much noise to be useful. In those
case the old school `debug log` can be benficial. The debug log format will always display unless Denizen is running in NO DEBUG
mode (which is NOT the default but may be active on servers).
    - Since Denizen is text only lists/maps are shown just fine, if hard to read. Tip: Copy and paste into most AI systems
    that are Denizen trained to review the data.
    - Consider adding a `-stop` to exit the script early, especially in loops, to avoid too much noise
    - If event is rare wrap in an '- if <...>:` condition to reduce noise. But remember to remove this code as it will impact performance
    even if just marginally.
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


## Name vs Simple

Most objects support `simple` and `name`. When should each be used?

Both .simple and .name are used to extract string versions of objects in Denizen, but they differ in what they return and how much detail they include.

- .simple
    - NOTE: material.simple is NOT supported for some objects (like items) in which case name is required. The VSCode plugin will verify
    that `.simple` is viable if it can determin the type. Otherwise search against Denizen documentation for '<object>Tag', for example `ItemTag`
    - Returns a clean, minimal string representation.
    - Removes prefixes like m@, i@, etc.
    - Great for basic comparisons.
    - Typically excludes metadata, like quantity or enchantments.
    - Example: <item[i@arrow[quantity=24]].material.simple> ==>  "arrow"

- .name
    - Works for most cases, but prefer `.simple` for quick lookups if it is supprted by the object
    - Returns the raw name of the object, possibly including more detail.
    - For materials, behaves similarly to .simple.
    - For more complex objects, .name might include suffixes or internal representations.
    - Example: <item[i@arrow[quantity=24]].material.name>  →  "arrow"  (same in this case)
    - But for other object types, .name might vary: <location[1,2,3,world].name>  →  "1,2,3,world"

- .simple is the cleanest base name, useful for Quick checks and comparisons
- .name	is a full object name, usefulf for display, logs, raw debugging

For your if statements — always prefer .simple when comparing IDs like arrow, stone, etc. It’s faster, clearer, and less error-prone.


## Dynamic-Boolean Context

There are numerous list functions and a few others, that support a boolean parmater. These usually include a special
loop local variable (definition) for use in the boolena construct. The boolean construct cannot use normal comparator operators. For example

- Loop on a list of item objects for any that are not 'air' and assign to not_air.
- define not_air inv_list.filter_tag[<[filter_value].material.name.equals[air].not]>
    - `filter_value` is the temporary define that `filter_tag` creates for the loop
    - we then get a plain name 'material.name'
    - 'equals' is the equivlent of '==' for If. Do NOT use '==' in dynamic-boolean context and it is NOT recomended to use 'equal' in 'if/while/etc.' constructs
    per Denizen documention.
        - See https://meta.denizenscript.com/Docs/Search/element.equals


Common Dynamic-Booleans

### Dynamic Boolean and Procedure-Based Operations in Denizen

NOTE: Please revie documentation for object types to see which of these apply to which objects and confirm they
are trully supported.

TODO: VET Dynamic Boolean table TABLE


### Denizen Dynamic Boolean and Procedure-Based Operations

| Object Type(s)      | Operation     | Type         | Description                                                               | Local Variable(s)           |
|---------------------|---------------|--------------|---------------------------------------------------------------------------|-----------------------------|
| ListTag, MapTag     | `filter_tag`  | Boolean      | Filters a collection based on a boolean tag condition.                    | `filter_value`              |
| ListTag, MapTag     | `find`        | Boolean      | Returns the first entry matching a condition.                             | `filter_value`              |
| ListTag, MapTag     | `any`         | Boolean      | Returns true if any entry satisfies the condition.                        | `filter_value`              |
| ListTag, MapTag     | `all`         | Boolean      | Returns true if all entries satisfy the condition.                        | `filter_value`              |
| ListTag, MapTag     | `none`        | Boolean      | Returns true if no entry satisfies the condition.                         | `filter_value`              |
| ListTag, MapTag     | `map_tag`     | Transformer  | Transforms each entry using a tag.                                        | `map_value`                 |
| ListTag             | `sort_tag`    | Sorter       | Sorts entries using a tag-based value for comparison.                     | `sort_value`                |
| ListTag             | `unique_tag`  | Transformer  | Removes duplicates using a tag-defined identity.                          | `unique_value`              |
| ListTag             | `group_tag`   | Grouper      | Groups entries by a tag-generated key.                                    | `group_value`               |
| ListTag             | `reduce_tag`  | Reducer      | Reduces list to a single value using an accumulator and logic tag.        | `reduce_value`, `reduce_accumulator` |
| ListTag             | `sort`        | Procedure    | Sorts entries using a procedure script for pairwise comparison.           | `value_one`, `value_two`    |
| ListTag             | `unique`      | Procedure    | Removes duplicates using a procedure script.                              | `value_one`, `value_two`    |
| ObjectTag (generic) | `proc`        | Procedure    | Calls a procedure script using the object as context.                     | `context`                   |


Notes:
- Boolean operations return true/false and typically filter or test lists.
- Transformer operations return modified versions of the list.
-   Procedure operations require a procedure script that returns a comparison result or transformed output. Procedure types often
support an additional `context` element to pass constant values.

Example of a procedure that given a list of locations sorts that list based on closest to the player (or any location element as passed):
- Usage : - `define by_closest <[location_list].sort[si__sort_by_distance].context[<player.location>]`


```
# ***
# *** Desigend to be called by a procedure based loop cosntruct such as `sort`
type: procedure
  definitions: a|b|feeder_loc
  debug: false
  script:
    - define da  <proc[si__distance].context[<[feeder_loc]>|<[a].get[t]>]>
    - define db  <proc[si__distance].context[<[feeder_loc]>|<[b].get[t]>]>
    - if <[da]>  < <[db]>:
        - determine -1
    - else:
        - if <[da]>  > <[db]>:
            - determine 1
    - determine 0

# ***
# *** get distance beteen a/b suitable for comparison. It does NOT caulcate
# *** an exact.
# ***
# **** Designed to be used by si__srt_by_distance, but accepts normal location data and
# **** uses internal distance(). In most cases that function is preferred for performance.
# ***
# ***
si__distance:
  type: procedure
  definitions: a|b
  debug: false
  script:
    - determine <[a].distance[<[b]>]>



```



### ElementTag Comparison Operators for Dynamic-Booleans

| Operator | ElementTag Method                        | Description                                      |
|----------|-------------------------------------------|--------------------------------------------------|
| `==`     | `.equals[<value>]`                        | Checks if two values are equal                   |
| `!=`     | `.equals[<value>].not`                    | Checks if values are not equal                   |
| `>`      | `.is_more_than[<value>]`                  | Greater than comparison                          |
| `<`      | `.is_less_than[<value>]`                  | Less than comparison                             |
| `>=`     | `.is_more_than_or_equal_to[<value>]`      | Greater than or equal comparison                 |
| `<=`     | `.is_less_than_or_equal_to[<value>]`      | Less than or equal comparison                    |
|          | `.is_odd`                                 | Checks if number is odd                          |
|          | `.is_even`                                | Checks if number is even                         |
|          | `.is_boolean`                             | True if value is `"true"` or `"false"`           |
|          | `.is_integer`                             | True if value is an integer                      |
|          | `.is_decimal`                             | True if value is a valid decimal number          |
|          | `.contains_text[<text>]`                  | Case-insensitive text contains                   |
|          | `.contains_case_sensitive_text[<text>]`   | Case-sensitive text contains                     |



## Using .is[==] and friends

There is also an syntax that si very poorly documented in Denizen that is `is[...].to/than`. Be careful using this
as it can make parsing challenging especially for '<', '>' and related elements that can get mistakenly parsed. In such
cases use the encoded text (&la, etc.). 

WARNING: Almost NO dcoumentation exists in Denizen for this construct. Bascially just one vague page and the '.is' on the
ElementTag page does not mention this at all. SO usage of these, while they worked last tested, are quite suscpect.

Equality and Inequality

    == or equals: Checks if two values are equal.​

<[value1].is[==].to[value2]>

!=: Checks if two values are not equal.​

    <[value1].is[!=].to[value2]>

* Numerical Comparisons

    > or more: Checks if the first value is greater than the second.​

<[value1].is[>].than[value2]>

< or less: Checks if the first value is less than the second.​

<[value1].is[<].than[value2]>

>= or or_more: Checks if the first value is greater than or equal to the second.​

<[value1].is[>=].than[value2]>

<= or or_less: Checks if the first value is less than or equal to the second.​

    <[value1].is[<=].than[value2]>

Note: When using <, >, <=, or >= within tags, ensure to escape them properly to avoid parsing issues. For example:​

<player.health.is[<&lt>].than[10]>

* Membership and Matching

    contains: Checks if a list or map contains a specific value.​

<[list].contains[value]>

in: Checks if a value is within a list or map.​

<[value].in[list]>

matches: Checks if a value matches a pattern or another value.​

    <[value].matches[pattern]>


See also https://meta.denizenscript.com/Docs/Languages/operator?utm_source=chatgpt.com which is summerized below. It only barely
mentions the 'is' construct:

Available Operators include:
"Equals" is written as "==" or "equals".
"Does not equal" is written as "!=".
"Is more than" is written as ">" or "more".
"Is less than" is written as "<" or "less".
"Is more than or equal to" is written as ">=" or "or_more".
"Is less than or equal to" is written as "<=" or "or_less".
"does this list or map contain" is written as "contains". For example, "- if a|b|c contains b:" or "- if [a=1;b=2] contains b:"
"is this in the list or map" is written as "in". For example, "- if b in a|b|c:", or "- if [a=1;b=2] contains b:"
"does this object or text match an advanced matcher" is written as "matches". For example, "- if <player.location.below> matches stone:"

Note: When using an operator in a tag,
keep in mind that < and >, and even >= and <= must be either escaped, or referred to by name.
Example: "<player.health.is[<&lt>].than[10]>" or "<player.health.is[less].than[10]>",
but <player.health.is[<].than[10]> will produce undesired results. <>'s must be escaped or replaced since
they are normally notation for a replaceable tag. Escaping is not necessary when the argument
contains no replaceable tags.

There are also special boolean operators (&&, ||, ...) documented at: Command:if


# Performance Tuning

 
- Get first non-empty item from an inventory (small chest every slot filled)
    - `<[feeder_inventory].map_slots.values.get[1]>`
        - 35ms per 10,000
        - NOTE: Technically this may not be in key (slot) order but I never saw a case where it wasn't. In any case I
        am fine with it being out of order if performance is signifcantly better
    - `<[feeder_inventory].list_contents.filter_tag[<[filter_value].material.name.is[==].to[air].not>].get[1]>`
        - 115ms per 10,000

    - Expected the map_slots to be much slower but it was actually quite a bite faster. Possibly since it can cache the value better and filters out air internally.
    Neither mode checks for an empty list as that is not aprt of this benchmark. But either is VERY fast.
    
- Chunk loaded check. There are cases where we often want to see if a chunk is loaded. General advice is to cache these values as the chunk laod chekc is slow. Is it?
    - Results: 2ms for 111 checks, with 74 locations expected to be loaded and another single and a single UNLOADED but processed 37 times
        - I think the simple `[loc].chunk.is_loaded>` is plenty fast AND even faster without all the overhead the benchmark adds
        - Conclusion: chunk.is_loaded appears to be FAST
    - Code:
    ```
        # Benchmark
        #  - useing a list of keys from the simple inventory module since that is what I am benchmarking
        - define items <[owner].flag[si.world.item].keys>
        - define counter 0
        - define cnt_loaded1 0
        - define cnt_loaded2 0
        - define cnt_loaded3 0
        - define tmp_start <util.current_time_millis>
        - define unloaded_loc <location[582,117,-837,world]>
        - foreach <[items]> as:item_name :
            - define loc_map <[owner].flag[si.world.item.<[item_name]>]>
            - foreach <[loc_map]> as:loc :
                - define l1 <[loc].get[t]>
                - define l2 <[loc].get[c]>
                - define l1_loaded <[l1].chunk.is_loaded>
                - define l2_loaded <[l1].chunk.is_loaded>
                - if <[l1_loaded]>:
                    - define cnt_loaded1 <[cnt_loaded1].add[1]>
                - if <[l2_loaded]>:
                    - define cnt_loaded2 <[cnt_loaded2].add[1]>
                - define l3_loaded <[unloaded_loc].chunk.is_loaded>
                - if <[l3_loaded]>:
                    - define cnt_loaded3 <[cnt_loaded3].add[1]>

                - define counter <[counter].add[3]>
        - define elapsed <util.current_time_millis.sub[<[tmp_start]>]>
        - define elapsed_chunk_loaded <[elapsed_chunk_loaded].add[<[elapsed]>]>
        - debug log "<red>Chunk load benchmark: <[counter]> locations checked in <[elapsed_chunk_loaded]> ms"
        - debug log "<red>   l1 = <[cnt_loaded1]> (loaded ok) expect count"
        - debug log "<red>   l2 = <[cnt_loaded2]> (loadd ok) expect count"
        - debug log "<red>   l3 = <[cnt_loaded3]> (loadd ok) expect 0"
        ```

## Trapping exceptions/errors

There is a way to trap exceptons, or at least some. When performing an command that might fail use the fallback of '.if_null[desired-value]'

This example will set target_inventory to null on failure and then a check can skip processing or whatever. Sometimes you may prefer false
or even a default. For example using `.if_null[list[]]` may be useful to just set up an empty loop with the need or overhead to abort
any operation.

The `.if_null` is special in that it CAPTURES an excpetiona nd prevents it from reaching the log files, this speeds up performance and
reduces console/log noise. While failed calls return null and do NOT cause Denizen scripts to exit (so excpetion is a not the ideal terminology)
a log/console entry is made which is really slow and makes the logs messay.

Tip: Skipping checks for existance or other attributes may allow for a significant performance boost and reliability assuming the failure case
is fraction of the normal case. Otherwise benchmark code to see if pre-checking or exception is better.

Note: The legacy mechanism was to use `||null` (or any other defualt). For example: `define target_inventory <[target_chest].inventory.||null>`.
That may still be required in some cases but Denizen documentation seems to favor using the `.if_null` even if all the documentation has not
been updated to reflect that.

```denizen
    - define target_inventory <[target_chest].inventory.if_null[null]>`
    - if <[target_inventory]> == null
        - narrate "<red>BAD BAD inventory, it broken. <[target_chest]>"
        - stop
```

### Using objects for fallback

When using a fallback command it is important to properly evaluate the contents.

- BAD: <[my_list].get[2].if_null[list[]]>
    - This resolves to the literal string 'list[]' which is NOT usually desired
- OK: <[my_list].get[2].if_null[@li]>
    - Not recomended as it is older syntax and using direct object notation is no longer recomended. Recall
    that all objects in Denizen are actually strings that are resolved by Denizen internals as needed and often
    intellignetly cached for performance. Normally developers do not need to be concerned unless benchmarks show a performance issue
- BEST: <[my_list].get[2].if_null[<[list[]]]>
    - The '<...>' is needed around the `list[]` (or whatever object is desired) to resolve this to an actual list and not treat as a literal

###	Tag Fallbacks

Reference: https://meta.denizenscript.com/Docs/Search/fallback and copied to below

NOTE: Please suggest using the newer form such as `.if_null[null]` instead of `||null` unless tne newer form is NOT supported for your specific case.

Description	Tag fallbacks (AKA "tag alternatives") are a system designed to allow scripters to automatically handle tag errors.

Fallbacks are implemented as special "magic tags" that look like any other tag-part, but override the error handler. These are "if_null", "exists", and "is_truthy".

A tag without a fallback might look like "<player.name>".
This tag works fine as long as there's a linked player, but what if a player isn't always available?
Normally, this situation would display an error in the console debug logs, and return plaintext "player.name" in the script.
A fallback can help us handle the problem more gracefully.
That same tag with a fallback would look like "<player.name.if_null[Steve]>".
Now, when there isn't a player available, there will not be an error, and the tag will simply return "Steve".

This format is the same for basically all tags. "<main.tag.here.if_null[Fallback here]>".
For another example, "<player.flag[myflag].if_null[0]>" returns either the value of the flag, or "0" if the flag is not present (or if there's no player).

The "exists" fallback-tag is available for checking whether an object exists and is valid.
What if we want to check if there even is a linked player? We don't have a "<has_player>" tag to do that, so what can we do?

- if <player.exists>:

The above example demonstrates using a fallback to check if a player is valid.
The if block will run only if there is not a player valid (you might, for example, place the "stop" command inside).

"Exists" is useful when you *only* need a check, however you often need to grab a value and verify it after.
Consider the following example, often found in command scripts:


- define target <server.match_player[<context.args.get[1]>].if_null[null]>
- if <[target]> == null:
    - narrate "<&[error]>Invalid player!"
    - stop
- narrate "<&[base]>You chose <&[emphasis]><[target].name><&[base]>!"

We use the word "null" in the above example, as well as in the tag name itself. This is a common programming term that means "no object is present".
"if_null" is the actual tag name, however the input value of "null" isn't actually a functionality of Denizen, it's just a word we choose for clarity.
You could just as easily do "- if <player.if_null[nothing]> == nothing:", or for that matter "- if <player.if_null[cheese]> == cheese:".
A player object takes the form "p@uuid", so it will therefore never exactly match any simple word, so there's no coincidental match edge-case to worry about.
Note that this won't work so perfect for things like a user input or fully dynamic value,
so in those cases you may want to use the "exists" tag explicitly to guarantee no potential conflict.

Fallbacks can be tags themselves. So, for example, if we want either a custom flag-based display name, or if not available, the player's base name,
we can do: "<player.flag[display_name].if_null[<player.name>]>".
You can as well chain these: "<player.flag[good_name].if_null[<player.flag[bad_name].if_null[<player.name>]>]>".

Note that fallbacks will *hide errors*. Generally, the only errors you should ever hide are ones you're expecting that are fine.
Don't use a fallback on a "<player.name>" tag, for example, if there should always be a player present when the script runs.
That tag should only ever have a fallback when the script is meant to still work without a player attached.
If you carelessly apply fallbacks to all tags, you might end up not realizing there's a problem in your script until it's affecting real players.
You want to solve errors in testing, not ten months later when a player mentions to you "that shop NPC let me buy things even when I had $0"!

Prior to Denizen 1.2.0, fallbacks exclusively worked with a special "||" syntax, like "- if <player||null> == null:"
This syntax is still fully supported at time of writing, however the newer tag-based format is considered clearer and easier to learn.



## Single line IF Commands deprecated

Can you remember that we should not combine IF and actions per:
- if <[dz]> < 0>: define planes <[planes].with[N].as[1]>

Error Message: Single line if commands are deprecated. Please update them to modern format (note: By deprecated they mean NO LONGER SUPPORTED)

Instead use:
- if <[dz]> < 0>:
  - define planes <[planes].with[N].as[1]>

## Optimize for ++, --, etc.

Some common operations can be optimized. For example
- define counter <[counter].add[1]>

Is optimized via. Benchmarks indicate there is very little, if any, performance difference but
it is easier to read. Also note that the definition (aka variable name) is a LITERAL text liek a normal define.

- define counter:++

This increments counter by 1 without needing to use .add[1].
This syntax is part of Data Actions, which allow quick and expressive value modifications:

- ++ → increment
- -- → decrement
- ! → remove
- +:<value> → add value
- -:<value> → subtract value

Examples:

- define x:++       # x becomes 1
- define y:+:3      # y becomes y + 3

Source: Denizen Documentation → Data Actions (language) section​.


## Queue stop vs stop

Name	Queue
Using the "stop" argument will force the queue to immediately stop running.
When trying to stop the current queue, use Command:stop instead.

Using the "delay:<duration>" argument will cause the queue to wait for a specified duration.
When trying to delay the current queue, use Command:wait instead.

Using the "pause" argument will freeze the queue but keep it listed, waiting for a "resume" instruction.
It is of course not possible to resume the current queue (as if you're running a 'queue' command, the queue can't be paused).

Generally, the queue command are considered a non-ideal way of doing things - that is, there's usually a better/cleaner way to achieve similar results.


See also Denizen Documentation for `Queue` at https://meta.denizenscript.com/Docs/Search/queue


## Create script constants

There are not really constants in Denzien but you can get pretty close by use a type:data script and a basic hierarchial stucture.

Example:

```denizen
si_config:
  type: data
  data:
    feeder:
        # Feeder location data (trigger) is proccessed every x ticks where the x is calculated
        # by a simple hash that when moded by tick_delay being zero the feeder is processed.
        #   Use 0 to fire every tick, useful for debugging
        tick_delay: 0
        max_slots: 1
        max_items: 64
        # 10 chunks which
        max_distance: 32
```

And the usage:

- define max_items `<script[si_config].data_key[data].get[feeder].get[max_items]>`

This can be broken down into:

- `script[si_config]` creates a script object. This could be assigned to a variable if desired, but many times that is not needed
- `data_key[data]` The data_key is used to fetch data from a script, in this case the 'data:' element. But there are many other per the `ScriptTag` in Denzien documentation
- `get[feeder].get[max_items]` - The data is a map, and as such you need to walk down the structure using multiple `get`, optionall ening with `.if_null[a-default]`


## Double Chest Nuances

Double blocks can present some interesting probles. For example when checking a block location of a double chest only the
specific block being checked contrinutes to the result. To manage a double block the following can be used, while
only tested on chests this should work on any double block. The key is to use '.other_block'.
 
This is a simple clean method, but may not be optimal. It uses fallbacks which are normally pretty quick. The
procedure returns greatest power level.

 ```denizen
powerlevel_blocks:
  type: procedure
  debug: false
  definitions: block
  script:
    #  Use fallbacks is usually faster than lots of checks
    - define other_block <[block].other_block.if_null[<[block]>]>
    - determine <[block].power.if_null[0].max[<[other_block].power.if_null[0]>]>
```

This example is more verbose but is 4x slower than above.  This
procedure also returns greatest power level.

```denizen
powerlevel_blocks_b:
  type: procedure
  debug: false
  definitions: chest_loc
  script:
    - define chest_block <[chest_loc].material>
    - define inv <[chest_loc].inventory>

    - define other_half <[chest_loc].other_block.if_null[null]>
    - if <[other_half]> != null:
        - define is_powered <[chest_loc].power.if_null[0].max[<[other_half].power.if_null[0]>]>
    - else:
        - define is_powered <[chest_loc].power.if_null[0]>
    - determine <[is_powered]>

```
