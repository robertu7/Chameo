# Location is sampled at capture time

Both apps attach only the optional location sampled when the photo is taken, rather than requesting a location when Save is tapped. This prevents a delayed or restored Preview from recording where the person later saved the photo instead of where it was captured; location failure or timeout remains non-blocking and produces a Chameo without location.
