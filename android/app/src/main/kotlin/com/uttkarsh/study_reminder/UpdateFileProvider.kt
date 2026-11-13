package com.uttkarsh.study_reminder

import androidx.core.content.FileProvider

/** Shares a downloaded update with Android's installer. Its own class, so it
 *  never clashes with a plugin's FileProvider in the merged manifest. */
class UpdateFileProvider : FileProvider()
