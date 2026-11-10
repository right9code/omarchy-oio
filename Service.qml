import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  // Check whether OIO is already installed before launching the installer.
  Process {
    id: checkOio
    command: ["bash", "-c", "test -x \"$HOME/.local/bin/oio\""]
    onExited: (code) => {
      if (code !== 0) {
        // Not installed yet -> launch installer in a floating terminal so sudo
        // can prompt interactively.
        installer.running = true
      }
    }
  }

  Process {
    id: installer
    command: ["omarchy-launch-floating-terminal-with-presentation", root.pluginDir + "/hooks/post-install.sh"]
  }

  Process {
    id: removeProcess
    command: ["bash", root.pluginDir + "/hooks/post-remove.sh"]
  }

  Component.onCompleted: {
    checkOio.running = true
  }

  Component.onDestruction: {
    removeProcess.running = true
  }
}
