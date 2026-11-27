// Fedora Mojo SDDM greeter. Mirrors the Plymouth boot theme's look (dark
// brand gradient, centered logo mark + wordmark) so the hand-off from boot
// splash to login screen reads as one continuous brand experience, then
// adds a glassmorphism-style card-style login form in place of
// SddmComponents' stock white-box widgets: soft blurred brand-color glow
// blobs behind a translucent, frosted-looking card.

import QtQuick 2.0
import QtQuick.Effects
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
    property color fgText: "#eef3fb"
    property color mutedText: "#9fb0d6"

    TextConstants { id: textConstants }

    gradient: Gradient {
        GradientStop { position: 0.0; color: container.bgTop }
        GradientStop { position: 1.0; color: container.bgBottom }
    }

    // Soft, blurred brand-color glow blobs -- the "texture" that reads
    // through the frosted card below. Blurring a flat 2-stop gradient
    // changes nothing visible, so these blobs exist specifically to give
    // the blur something to do.
    Item {
        id: backdrop
        anchors.fill: parent

        Rectangle {
            width: container.width * 0.5; height: width; radius: width / 2
            x: container.width * 0.08; y: container.height * 0.05
            color: accent; opacity: 0.35
        }
        Rectangle {
            width: container.width * 0.4; height: width; radius: width / 2
            x: container.width * 0.65; y: container.height * 0.5
            color: cardBorder; opacity: 0.4
        }
        Rectangle {
            width: container.width * 0.3; height: width; radius: width / 2
            x: container.width * 0.1; y: container.height * 0.55
            color: "#3c58a3"; opacity: 0.3
        }
    }

    MultiEffect {
        anchors.fill: backdrop
        source: backdrop
        autoPaddingEnabled: true
        blurEnabled: true
        blur: 1.0
        blurMax: 250
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
            color: fgText
            font.family: "Montserrat"
            font.bold: true
            font.pixelSize: 22
            font.letterSpacing: 2
        }
    }

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 0.7
        shadowVerticalOffset: 10
        shadowHorizontalOffset: 0
    }

    // Card-style login form, replacing the stock theme's plain white box
    // with a frosted-glass one: translucent fill over the blurred glow
    // blobs above, a light (not brand-dark) border for a glass edge, a
    // soft drop shadow for elevation, and a thin top highlight for sheen.
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: brandColumn.bottom
        anchors.topMargin: 36
        width: 400
        height: formColumn.implicitHeight + 56
        radius: 22
        color: Qt.rgba(cardColor.r, cardColor.g, cardColor.b, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: parent.height * 0.4
            radius: parent.radius - 1
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        Column {
            id: formColumn
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                width: parent.width
                text: textConstants.welcomeText.arg(sddm.hostName)
                color: fgText
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
                    color: Qt.rgba(13/255, 21/255, 38/255, 0.55)
                    borderColor: cardBorder
                    focusColor: accent
                    textColor: fgText
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
                    color: Qt.rgba(13/255, 21/255, 38/255, 0.55)
                    borderColor: cardBorder
                    focusColor: accent
                    textColor: fgText
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
                        color: Qt.rgba(13/255, 21/255, 38/255, 0.55)
                        borderColor: cardBorder
                        focusColor: accent
                        menuColor: cardColor
                        textColor: fgText
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
                        color: Qt.rgba(13/255, 21/255, 38/255, 0.55)
                        borderColor: cardBorder
                        focusColor: accent
                        menuColor: cardColor
                        textColor: fgText
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
                    // A deeper blue than the brand accent used elsewhere --
                    // accent's own ~4:1 contrast with dark text (or white
                    // text) was too close to the WCAG AA line; this pairs
                    // with white text at a solid ~6.7:1.
                    color: "#3c58a3"
                    activeColor: accent
                    pressedColor: "#2c4178"
                    textColor: "#ffffff"
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
