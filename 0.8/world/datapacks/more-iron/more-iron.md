# More Iron, Less Copper – Datapack

This datapack rebalances Minecraft's ore generation to reduce the overwhelming amount of copper and improve iron availability for utility and gameplay flow (especially with ore scanner tools).

## ✅ Summary of Changes
- **Copper total ore blocks per chunk**: ~480 → ~125
- **Iron total ore blocks per chunk (excluding mountain layer)**: ~130 → ~221
- Adjusts only naturally-generated ore layers — existing terrain will not be affected unless regenerated.

## 💡 Usage
Upload this ZIP to your server's `world/datapacks/` directory. Do not unzip it.
After uploading:
- Run `/reload` or restart the server.
- Check it's loaded using `/datapack list`.

---

🛠️ This datapack was generated with help from **ChatGPT**.

You can regenerate it using a prompt like:
> "Using this Markdown table of ore settings, generate a Minecraft 1.21 datapack that modifies `configured_feature` and `placed_feature` to match the new values, includes a markdown summary with the table, and adds inline comments in each JSON to indicate original values."

---

## 🗃️ Config Changes

| File Type | File Name          | Key   | Vanilla Value | New Value | Layer       | Notes |
|-----------|--------------------|-------|----------------|------------|--------------|-------|
| Feature   | ore_iron           | size  | 9              | 11         |              | Increased to balance copper cut |
| Feature   | ore_iron_small     | size  | 4              | 6          |              | Increased to balance copper cut |
| Feature   | ore_copper_large   | size  | 20             | 10         |              | Reduced to lower noise |
| Feature   | ore_copper_small   | size  | 10             | 5          |              | Reduced to lower noise |
| Placed    | ore_iron_middle    | count | 10             | 13         | -24 → 56     | Adjusted to balance copper cut |
| Placed    | ore_iron_small     | count | 10             | 13         | 0 → 72       | Adjusted to balance copper cut |
| Placed    | ore_iron_upper     | count | 90             | 90         | 80 → 384     | Kept unchanged |
| Placed    | ore_copper         | count | 16             | 5          | -16 → 112    | Reduced to lower noise |
| Placed    | ore_copper_large   | count | 16             | 10         | -16 → 112    | Reduced to lower noise |
