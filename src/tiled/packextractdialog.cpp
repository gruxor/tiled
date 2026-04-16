#include "packextractdialog.h"
#include "ui_packextractdialog.h"

#include "texturepackfile.h"

#include "BuildingEditor/buildingtiles.h"

#include <QButtonGroup>
#include <QDebug>
#include <QFileDialog>
#include <QMessageBox>
#include <QPainter>
#include <QSettings>

PackExtractDialog::PackExtractDialog(PackFile &packFile, QWidget *parent) :
    QDialog(parent),
    ui(new Ui::PackExtractDialog),
    mPackFile(packFile)
{
    ui->setupUi(this);

    connect(ui->outputBrowse, &QAbstractButton::clicked, this, &PackExtractDialog::browse);
    connect(ui->radioSingle, &QRadioButton::toggled, this, &PackExtractDialog::radioToggled);

    ui->radioMultiple->setChecked(true);
    ui->radioSingle->setChecked(false);
    ui->checkBox2x->setChecked(true);
    ui->checkBox2x->setEnabled(ui->radioSingle->isChecked());
    ui->checkBoxWWO->setEnabled(true);
    ui->checkBoxWWO->setChecked(true);
    ui->checkBoxMultiTileSheets->setChecked(false);
    ui->checkBoxMultiTileSheets->setEnabled(true);

    QSettings settings;
    settings.beginGroup(QStringLiteral("PackExtractDialog"));
    ui->radioSingle->setChecked(settings.value(QStringLiteral("IsTilesheet"), false).toBool());
    ui->prefixEdit->setText(settings.value(QStringLiteral("Prefix")).toString());
    ui->outputEdit->setText(settings.value(QStringLiteral("OutputDirectory")).toString());
    settings.endGroup();
}

PackExtractDialog::~PackExtractDialog()
{
    delete ui;
}

void PackExtractDialog::browse()
{
    QString f = QFileDialog::getExistingDirectory(this, tr("Choose output directory"), ui->outputEdit->text());
    if (!f.isEmpty()) {
        ui->outputEdit->setText(QDir::toNativeSeparators(f));
    }
}

void PackExtractDialog::accept()
{
    QString prefix = ui->prefixEdit->text();
//    if (prefix.isEmpty())
//        return;

    QDir outputDir(ui->outputEdit->text());
    if (!outputDir.exists()) {
        QMessageBox::warning(this, tr("Extract .pack Images"),
                             tr("The output directory does not exist:\n%1").arg(outputDir.path()));
        return;
    }

    if (ui->radioSingle->isChecked() && prefix.isEmpty()) {
        QMessageBox::warning(this, tr("Extract .pack Images"),
                             tr("Prefix is required when creating a single tilesheet.\nEnter the tileset name (e.g. \"appliances_cooking_01\")."));
        return;
    }

    QSettings settings;
    settings.beginGroup(QStringLiteral("PackExtractDialog"));
    settings.setValue(QStringLiteral("IsTilesheet"), ui->radioSingle->isChecked());
    settings.setValue(QStringLiteral("Prefix"), prefix);
    settings.setValue(QStringLiteral("OutputDirectory"), outputDir.path());
    settings.endGroup();

    int savedCount = 0;

    if (ui->radioMultiple->isChecked()) {
        foreach (PackPage page, mPackFile.pages()) {
            foreach (PackSubTexInfo tex, page.mInfo) {
                if (prefix.isEmpty() || tex.name.startsWith(prefix, Qt::CaseInsensitive)) {
                    QImage image(tex.fx, tex.fy, QImage::Format_ARGB32);
                    image.fill(Qt::transparent);
                    QPainter painter(&image);
                    painter.drawImage(tex.ox, tex.oy, page.image, tex.x, tex.y, tex.w, tex.h);
                    painter.end();
                    QString filePath = outputDir.filePath(tex.name + QStringLiteral(".png"));
                    // make any directories (if tex.name contains any separators)
                    QFileInfo fi(filePath);
                    if (!fi.dir().exists())
                        fi.dir().mkpath(QLatin1String("."));
                    if (image.save(filePath, "PNG", -1))
                        savedCount++;
                    else
                        qWarning() << "PackExtractDialog: failed to save" << filePath;
                }
            }
        }
    } else {
        struct TileInfo {
            QString tileName;
            int tileIndex;
            QImage tileImage;
            QRect tileRect;
        };
        QRect bounds(0, 0, 0, 0);
        QList<TileInfo> tiles;
        int TileScale = ui->checkBox2x->isChecked() ? 2 : 1;
        const int tileW = 64 * TileScale;
        const int tileH = 128 * TileScale;
        foreach (PackPage page, mPackFile.pages()) {
            foreach (PackSubTexInfo tex, page.mInfo) {
                if (tex.name.startsWith(prefix, Qt::CaseInsensitive)) {
                    QString tileName;
                    int tileIndex;
                    if (BuildingEditor::BuildingTilesMgr::parseTileName(tex.name, tileName, tileIndex)) {
                        if (tex.fx != tileW || tex.fy != tileH) {
                            qDebug() << QStringLiteral("WARNING: %1 size %2x%3 is not %4x%5").arg(tex.name).arg(tex.fx).arg(tex.fy).arg(tileW).arg(tileH);
                        }
                        QImage image(tex.fx, tex.fy, QImage::Format_ARGB32);
                        image.fill(Qt::transparent);
                        QPainter painter(&image);
                        painter.drawImage(tex.ox, tex.oy, page.image, tex.x, tex.y, tex.w, tex.h);
                        painter.end();

                        TileInfo info;
                        info.tileName = tileName;
                        info.tileIndex = tileIndex;
                        info.tileImage = image;
                        info.tileRect = QRect((tileIndex % 8) * tileW, (tileIndex / 8) * tileH, tileW, tileH);
                        tiles += info;

                        bounds |= info.tileRect;
                    }
                }
            }
        }
        if (!bounds.isEmpty()) {
            QImage image(bounds.size(), QImage::Format_ARGB32);
            image.fill(Qt::transparent);
            foreach (TileInfo info, tiles) {
                QPainter painter(&image);
                painter.drawImage(info.tileRect.topLeft(), info.tileImage);
                painter.end();
            }
            QString filePath = outputDir.filePath(prefix + QLatin1String(".png"));
            if (image.save(filePath, "PNG", -1))
                savedCount++;
            else
                qWarning() << "PackExtractDialog: failed to save" << filePath;
        } else {
            QMessageBox::warning(this, tr("Extract .pack Images"),
                                 tr("No tiles with prefix \"%1\" were found in the .pack file.").arg(prefix));
            return;
        }
    }

    if (savedCount == 0) {
        QMessageBox::warning(this, tr("Extract .pack Images"),
                             tr("No images were extracted. Check that the path is writable and the prefix matches tiles in the .pack file."));
    } else {
        QMessageBox::information(this, tr("Extract .pack Images"),
                                 tr("Extracted %1 image(s) to:\n%2").arg(savedCount).arg(outputDir.path()));
    }

    QDialog::accept();
}

void PackExtractDialog::radioToggled()
{
    ui->checkBox2x->setEnabled(ui->radioSingle->isChecked());
}
