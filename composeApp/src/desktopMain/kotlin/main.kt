import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import com.softify.app.ui.App
import uniffi.softify_core.initDatabase
import java.io.File

fun main() = application {
    val homeDir = System.getProperty("user.home")
    val dbDir = File(homeDir, ".softify")
    if (!dbDir.exists()) {
        dbDir.mkdirs()
    }
    val dbPath = File(dbDir, "softify.db").absolutePath
    try {
        initDatabase(dbPath)
    } catch (e: Exception) {
        println("[Desktop] Database init notice: ${e.message}")
    }

    Window(onCloseRequest = ::exitApplication, title = "Softify") {
        App()
    }
}
