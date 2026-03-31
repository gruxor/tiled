/*
 * Copyright 2013, Tim Baker <treectrl@users.sf.net>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "configdialog.h"
#include "ui_configdialog.h"

#include <QFileDialog>
#include <QDir>
#include <QSettings>

static QString KEY_CONFIG_DIR = QLatin1String("ConfigDirectory");

ConfigDialog::ConfigDialog(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::ConfigDialog)
{
    ui->setupUi(this);

    // Utiliser le fichier settings.ini
    QSettings settings(QCoreApplication::applicationDirPath() + QLatin1String("/settings.ini"), QSettings::IniFormat);

    QString defaultPath = QCoreApplication::applicationDirPath() + QLatin1String("/.TileZed");
    QString configPath = settings.value(KEY_CONFIG_DIR, defaultPath).toString();
    ui->configDirectory->setText(configPath);

    connect(ui->configBrowse, &QAbstractButton::clicked, this, &ConfigDialog::configBrowse);
}

ConfigDialog::~ConfigDialog()
{
    delete ui;
}

void ConfigDialog::configBrowse()
{
    QString f = QFileDialog::getExistingDirectory(this, tr("Config Directory"),
                                                  ui->configDirectory->text());
    if (!f.isEmpty()) {
        ui->configDirectory->setText(QDir::toNativeSeparators(f));
    }
}

void ConfigDialog::accept()
{
    QSettings settings(QDir::currentPath() + QLatin1String("/settings.ini"), QSettings::IniFormat);
    settings.setValue(KEY_CONFIG_DIR, ui->configDirectory->text());
    QDialog::accept();
}
