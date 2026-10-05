// M1B2-A isolated QA candidate. This build does not deploy Firebase Functions,
// register production credentials, or enable the plugin in project.godot.
plugins {
    id("com.android.library") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
}
