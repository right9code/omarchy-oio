import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  Process {
    id: installProcess
    command: ["bash", root.pluginDir + "/hooks/post-install.sh"]
  }

  Process {
    id: removeProcess
    command: ["bash", root.pluginDir + "/hooks/post-remove.sh"]
  }

  Component.onCompleted: {
    installProcess.running = true
  }

  Component.onDestruction: {
    removeProcess.running = true
  }
}
