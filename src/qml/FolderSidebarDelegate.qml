import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.ItemDelegate {
    id: item

    required property TreeView treeView
    required property int row
    required property int column
    required property int depth
    required property bool expanded
    required property bool hasChildren

    // Model roles
    required property int accountId
    required property string path
    required property int unreadCount
    required property bool isAccountHeader
    required property string email
    required property string displayName
    required property string iconName
    required property bool isEssential

    signal folderSelected(int accountId, string folderPath)
    signal saveSelection(int accountId, string folderPath)

    width: treeView.width
    height: delegateContent.implicitHeight + Kirigami.Units.smallSpacing * 2

    contentItem: RowLayout {
        id: delegateContent
        spacing: Kirigami.Units.smallSpacing

        // Arrow column: depth spacer + arrow (or empty placeholder)
        Item {
            Layout.preferredWidth: item.depth * Kirigami.Units.largeSpacing + 12
            Layout.preferredHeight: 12

            Kirigami.Icon {
                id: arrowIcon
                anchors.left: parent.left
                anchors.leftMargin: item.depth * Kirigami.Units.largeSpacing
                source: item.expanded ? "arrow-down" : "arrow-right"
                width: 12
                height: 12
                visible: item.hasChildren

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (item.expanded) {
                            item.treeView.collapse(item.row);
                        } else {
                            item.treeView.expand(item.row);
                        }
                    }
                }
            }
        }

        // Folder icon (always at the same column, straight line)
        Kirigami.Icon {
            source: item.iconName.length > 0 ? item.iconName : (item.isAccountHeader ? "user" : "folder-mail")
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }

        Item {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 2
        }

        // Email label (account header)
        Controls.Label {
            text: item.email.length > 0 ? item.email : item.displayName
            font.weight: Font.Bold
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: item.isAccountHeader
        }

        // Folder name
        Controls.Label {
            text: item.displayName
            Layout.fillWidth: true
            font.weight: item.unreadCount > 0 ? Font.Bold : Font.Normal
            elide: Text.ElideRight
            visible: !item.isAccountHeader
        }

        // Unread badge
        Controls.Label {
            text: item.unreadCount > 0 ? item.unreadCount.toString() : ""
            color: Kirigami.Theme.highlightColor
            font.pointSize: 10
            visible: !item.isAccountHeader && item.unreadCount > 0
        }
    }

    onClicked: {
        if (item.hasChildren) {
            if (item.expanded) {
                treeView.collapse(item.row);
            } else {
                treeView.expand(item.row);
            }
        }
        if (!item.isAccountHeader) {
            var folderPath = item.path.length > 0 ? item.path : item.displayName;
            item.folderSelected(item.accountId, folderPath);
            item.saveSelection(item.accountId, folderPath);
        }
    }
}
