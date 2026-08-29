# Use one product bundle identifier

The Mac, iPhone, and iPad apps use the bundle identifier `com.robertu.Chameo`. They are platform-specific implementations of the same Chameo product even though the Mac and mobile apps have independent build systems, version numbers, and release schedules.

Sharing the product identifier preserves a consistent Apple-platform identity and leaves open a future unified App Store product strategy. It does not introduce application-level synchronization: the Photos album remains the only cross-device state. A separate mobile identifier would be appropriate only if mobile becomes a distinct product, which is not the current intent.
