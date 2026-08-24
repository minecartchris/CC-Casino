-- Machine-specific hardware config for Roulette.lua.
-- Update these values to match THIS computer's actual wiring - don't copy
-- this file's values as-is to a different machine.
return {
  -- Side the wired modem is on (used for rednet.open).
  modemSide = "back",

  -- Name of THIS machine's card reader peripheral. Use a plain side name
  -- (e.g. "left") if the reader is directly touching this computer, or its
  -- networked peripheral name (e.g. "nfc_reader_12") if it's reachable only
  -- over the wired modem network. Run `peripheral.getNames()` in the lua
  -- prompt once the reader is placed and wired to find its exact name.
  --
  -- Left nil until the reader exists - Roulette.lua will refuse to start
  -- with a clear error instead of silently trusting whichever reader
  -- happens to answer on the shared network.
  nfcName = "nfc_reader_33",
}
