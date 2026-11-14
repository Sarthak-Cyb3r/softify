package com.softify.app

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Strict Unit Test ensuring zero emojis or emoji-like pictographic glyphs exist
 * in any Kotlin source file under composeApp.
 */
class NoEmojiTest {

    private val forbiddenGlyphs = setOf(
        "♪", "♫", "★", "☆", "♥", "♡", "✕", "✖", "⚙", "🛠", "🐞"
    )

    private fun isEmojiOrPictograph(codePoint: Int): Boolean {
        if (codePoint in 0x1F300..0x1FAFF) return true // Miscellaneous Symbols and Pictographs, Emoticons, etc.
        if (codePoint in 0x2600..0x27BF) return true   // Miscellaneous Symbols, Dingbats
        if (codePoint in 0x2B00..0x2BFF) return true   // Miscellaneous Symbols and Arrows
        if (codePoint == 0xFE0F) return true          // Variation Selector-16 (Emoji presentation)
        return false
    }

    @Test
    fun testNoEmojisInComposeSourceFiles() {
        val rootDir = if (File("composeApp").exists()) File(".") else File("..")
        val composeAppSrc = File(rootDir, "composeApp/src")
        assertTrue(composeAppSrc.exists(), "composeApp/src directory must exist at: ${composeAppSrc.absolutePath}")

        val violations = mutableListOf<String>()

        composeAppSrc.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            // Ignore this test file itself since it defines forbidden glyphs
            .filter { it.name != "NoEmojiTest.kt" }
            .forEach { file ->
                val lines = file.readLines()
                for ((lineIndex, line) in lines.withIndex()) {
                    // 1. Check specific forbidden glyphs
                    for (glyph in forbiddenGlyphs) {
                        if (line.contains(glyph)) {
                            val relativePath = file.relativeTo(rootDir).path
                            violations.add("$relativePath:${lineIndex + 1} contains forbidden glyph '$glyph'")
                        }
                    }

                    // 2. Check Unicode code point ranges
                    var i = 0
                    while (i < line.length) {
                        val codePoint = line.codePointAt(i)
                        if (isEmojiOrPictograph(codePoint)) {
                            val charStr = String(Character.toChars(codePoint))
                            val relativePath = file.relativeTo(rootDir).path
                            violations.add("$relativePath:${lineIndex + 1} contains forbidden code point '$charStr' (U+${codePoint.toString(16).uppercase()})")
                        }
                        i += Character.charCount(codePoint)
                    }
                }
            }

        assertTrue(
            violations.isEmpty(),
            "Found ${violations.size} forbidden emoji/pictograph glyph(s) in Compose source files:\n" +
                violations.joinToString("\n")
        )
    }
}
