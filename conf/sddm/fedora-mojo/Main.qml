// Fedora Mojo SDDM greeter. Mirrors the Plymouth boot theme's look (dark
// brand gradient, centered logo mark + wordmark) so the hand-off from boot
// splash to login screen reads as one continuous brand experience, then
// adds a card-style login form in place of SddmComponents' stock
// white-box widgets.

import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: container
    width: 1024
    height: 768

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index

    // Brand palette -- kept in sync with conf/plymouth/fedora-mojo/fedora-mojo.script.
    property color bgTop: "#1b2a4a"
    property color bgBottom: "#0d1526"
    property color cardColor: "#17233d"
    property color cardBorder: "#3d5a99"
    property color accent: "#5b7fd4"
    property color textColor: "#eef3fb"
    property color mutedText: "#9fb0d6"

    TextConstants { id: textConstants }

    gradient: Gradient {
        GradientStop { position: 0.0; color: container.bgTop }
        GradientStop { position: 1.0; color: container.bgBottom }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = accent
            errorMessage.text = textConstants.loginSucceeded
        }
        function onLoginFailed() {
            password.text = ""
            errorMessage.color = "#e2685f"
            errorMessage.text = textConstants.loginFailed
        }
        function onInformationMessage(message) {
            errorMessage.color = "#e2685f"
            errorMessage.text = message
        }
    }

    Clock {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        color: mutedText
        timeFont.family: "Montserrat"
    }

    Column {
        id: brandColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(48, container.height * 0.1)
        spacing: 16

        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl("logo-mark.png")
            width: Math.min(96, container.height * 0.12)
            height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "FEDORA MOJO"
            color: textColor
            font.family: "Montserrat"
            font.bold: true
            font.pixelSize: 22
            font.letterSpacing: 2
        }
    }

    // Card-style login form, replacing the stock theme's plain white box.
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: brandColumn.bottom
        anchors.topMargin: 36
        width: 400
        height: formColumn.implicitHeight + 56
        radius: 18
        color: cardColor
        border.color: cardBorder
        border.width: 1

        Column {
            id: formColumn
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                width: parent.width
                text: textConstants.welcomeText.arg(sddm.hostName)
                color: textColor
                font.family: "Montserrat"
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: textConstants.userName
                    color: mutedText
                    font.family: "Montserrat"
                    font.pixelSize: 12
                }

                TextBox {
                    id: name
                    width: parent.width; height: 36
                    radius: 10
                    color: "#0d1526"
                    borderColor: cardBorder
                    focusColor: accent
                    textColor: textColor
                    font.pixelSize: 14
                    text: userModel.lastUser

                    KeyNavigation.backtab: rebootButton; KeyNavigation.tab: password

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: textConstants.password
                    color: mutedText
                    font.family: "Montserrat"
                    font.pixelSize: 12
                }

                PasswordBox {
                    id: password
                    width: parent.width; height: 36
                    radius: 10
                    color: "#0d1526"
                    borderColor: cardBorder
                    focusColor: accent
                    textColor: textColor
                    font.pixelSize: 14

                    KeyNavigation.backtab: name; KeyNavigation.tab: session

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                Column {
                    width: (parent.width - 8) * 0.5
                    spacing: 6

                    Text {
                        text: textConstants.session
                        color: mutedText
                        font.family: "Montserrat"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: session
                        width: parent.width; height: 34
                        color: "#0d1526"
                        borderColor: cardBorder
                        focusColor: accent
                        menuColor: cardColor
                        textColor: textColor
                        font.pixelSize: 13
                        arrowIcon: Qt.resolvedUrl("angle-down.png")

                        model: sessionModel
                        index: sessionModel.lastIndex

                        KeyNavigation.backtab: password; KeyNavigation.tab: layoutBox
                    }
                }

                Column {
                    width: (parent.width - 8) * 0.5
                    spacing: 6
                    visible: keyboard.enabled && keyboard.layouts.length > 0

                    Text {
                        text: textConstants.layout
                        color: mutedText
                        font.family: "Montserrat"
                        font.pixelSize: 12
                    }

                    LayoutBox {
                        id: layoutBox
                        width: parent.width; height: 34
                        color: "#0d1526"
                        borderColor: cardBorder
                        focusColor: accent
                        menuColor: cardColor
                        textColor: textColor
                        font.pixelSize: 13
                        arrowIcon: Qt.resolvedUrl("angle-down.png")

                        // Stock rowDelegate draws flag + language code with no
                        // margin reserved for the arrow in LTR layouts, so the
                        // code overlaps it. A single keyboard layout is the
                        // common case anyway, so just show the flag.
                        rowDelegate: Rectangle {
                            color: "transparent"
                            Image {
                                anchors.centerIn: parent
                                anchors.margins: 4
                                fillMode: Image.PreserveAspectFit
                                height: parent.height - 8
                                source: "/usr/share/sddm/flags/%1.png".arg(modelItem ? modelItem.modelData.shortName : "zz")
                            }
                        }

                        KeyNavigation.backtab: session; KeyNavigation.tab: loginButton
                    }
                }
            }

            Text {
                id: errorMessage
                width: parent.width
                text: textConstants.prompt
                color: mutedText
                font.family: "Montserrat"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Button {
                    id: loginButton
                    text: textConstants.login
                    width: 96; height: 36
                    radius: 10
                    color: accent
                    activeColor: "#4a6bc0"
                    pressedColor: "#3c58a3"
                    textColor: "#0d1526"
                    font.bold: true

                    onClicked: sddm.login(name.text, password.text, sessionIndex)

                    KeyNavigation.backtab: layoutBox; KeyNavigation.tab: shutdownButton
                }

                Button {
                    id: shutdownButton
                    text: textConstants.shutdown
                    width: 96; height: 36
                    radius: 10
                    color: "transparent"
                    borderColor: cardBorder
                    activeColor: cardBorder
                    pressedColor: cardBorder
                    textColor: mutedText

                    onClicked: sddm.powerOff()

                    KeyNavigation.backtab: loginButton; KeyNavigation.tab: rebootButton
                }

                Button {
                    id: rebootButton
                    text: textConstants.reboot
                    width: 96; height: 36
                    radius: 10
                    color: "transparent"
                    borderColor: cardBorder
                    activeColor: cardBorder
                    pressedColor: cardBorder
                    textColor: mutedText

                    onClicked: sddm.reboot()

                    KeyNavigation.backtab: shutdownButton; KeyNavigation.tab: name
                }
            }
        }
    }

    Component.onCompleted: {
        if (name.text == "")
            name.focus = true
        else
            password.focus = true
    }
}
