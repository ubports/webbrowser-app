/*
 * Copyright 2013 Canonical Ltd.
 *
 * This file is part of ubuntu-browser.
 *
 * ubuntu-browser is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * ubuntu-browser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// Qt
#include <QtTest/QtTest>

// local
#include "commandline-parser.h"

class CommandLineParserTests : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void shouldDisplayHelp_data()
    {
        QTest::addColumn<QStringList>("args");
        QTest::addColumn<bool>("help");
        QString BINARY("ubuntu-browser");
        QString URL("http://ubuntu.com");
        QTest::newRow("no switch") << (QStringList() << BINARY) << false;
        QTest::newRow("no switch with URL") << (QStringList() << BINARY << URL) << false;
        QTest::newRow("short switch only") << (QStringList() << BINARY << "-h") << true;
        QTest::newRow("long switch only") << (QStringList() << BINARY << "--help") << true;
        QTest::newRow("short switch before URL") << (QStringList() << BINARY << "-h" << URL) << true;
        QTest::newRow("long switch before URL") << (QStringList() << BINARY << "--help" << URL) << true;
        QTest::newRow("short switch after URL") << (QStringList() << BINARY << URL << "-h") << true;
        QTest::newRow("long switch after URL") << (QStringList() << BINARY << URL << "--help") << true;
        QTest::newRow("short switch typo") << (QStringList() << BINARY << "-j") << false;
        QTest::newRow("long switch typo") << (QStringList() << BINARY << "--helo") << false;
        QTest::newRow("short switch long") << (QStringList() << BINARY << "--h") << false;
        QTest::newRow("long switch short") << (QStringList() << BINARY << "-help") << false;
        QTest::newRow("short switch uppercase") << (QStringList() << BINARY << "-H") << false;
        QTest::newRow("long switch uppercase") << (QStringList() << BINARY << "--HELP") << false;
    }

    void shouldDisplayHelp()
    {
        QFETCH(QStringList, args);
        QFETCH(bool, help);
        QCOMPARE(CommandLineParser(args).help(), help);
    }

    void shouldBeChromeless_data()
    {
        QTest::addColumn<QStringList>("args");
        QTest::addColumn<bool>("chromeless");
        QString BINARY("ubuntu-browser");
        QString URL("http://ubuntu.com");
        QTest::newRow("no switch") << (QStringList() << BINARY) << false;
        QTest::newRow("switch only") << (QStringList() << BINARY << "--chromeless") << true;
        QTest::newRow("switch before URL") << (QStringList() << BINARY << "--chromeless" << URL) << true;
        QTest::newRow("switch after URL") << (QStringList() << BINARY << URL << "--chromeless") << true;
        QTest::newRow("switch typo") << (QStringList() << BINARY << "--chromeles") << false;
        QTest::newRow("switch uppercase") << (QStringList() << BINARY << "--CHROMELESS") << false;
        QTest::newRow("help precludes other switches") << (QStringList() << BINARY << "-h" << "--chromeless") << false;
        QTest::newRow("help precludes other switches") << (QStringList() << BINARY << "--help" << "--chromeless") << false;
    }

    void shouldBeChromeless()
    {
        QFETCH(QStringList, args);
        QFETCH(bool, chromeless);
        QCOMPARE(CommandLineParser(args).chromeless(), chromeless);
    }

    void shouldBeFullscreen_data()
    {
        QTest::addColumn<QStringList>("args");
        QTest::addColumn<bool>("fullscreen");
        QString BINARY("ubuntu-browser");
        QString URL("http://ubuntu.com");
        QTest::newRow("no switch") << (QStringList() << BINARY) << false;
        QTest::newRow("switch only") << (QStringList() << BINARY << "--fullscreen") << true;
        QTest::newRow("switch before URL") << (QStringList() << BINARY << "--fullscreen" << URL) << true;
        QTest::newRow("switch after URL") << (QStringList() << BINARY << URL << "--fullscreen") << true;
        QTest::newRow("switch typo") << (QStringList() << BINARY << "--fulscreen") << false;
        QTest::newRow("switch uppercase") << (QStringList() << BINARY << "--FULLSCREEN") << false;
        QTest::newRow("help precludes other switches") << (QStringList() << BINARY << "-h" << "--fullscreen") << false;
        QTest::newRow("help precludes other switches") << (QStringList() << BINARY << "--help" << "--fullscreen") << false;
    }

    void shouldBeFullscreen()
    {
        QFETCH(QStringList, args);
        QFETCH(bool, fullscreen);
        QCOMPARE(CommandLineParser(args).fullscreen(), fullscreen);
    }

    void shouldRecordURL_data()
    {
        QTest::addColumn<QStringList>("args");
        QTest::addColumn<QUrl>("url");
        QString BINARY("ubuntu-browser");
        QString DEFAULT("http://www.ubuntu.com");
        QString URL1("http://example.org");
        QString URL2("http://example.com");
        QTest::newRow("no URL") << (QStringList() << BINARY) << QUrl(DEFAULT);
        QTest::newRow("no URL with switches") << (QStringList() << BINARY << "--chromeless" << "--fullscreen") << QUrl(DEFAULT);
        QTest::newRow("help precludes URL") << (QStringList() << BINARY << "-h" << URL1) << QUrl(DEFAULT);
        QTest::newRow("help precludes URL") << (QStringList() << BINARY << "--help" << URL1) << QUrl(DEFAULT);
        QTest::newRow("one URL") << (QStringList() << BINARY << URL1) << QUrl(URL1);
        QTest::newRow("several URLs") << (QStringList() << BINARY << URL1 << URL2) << QUrl(URL1);
    }

    void shouldRecordURL()
    {
        QFETCH(QStringList, args);
        QFETCH(QUrl, url);
        QCOMPARE(CommandLineParser(args).url(), url);
    }
};

QTEST_MAIN(CommandLineParserTests)
#include "tst_CommandLineParserTests.moc"
