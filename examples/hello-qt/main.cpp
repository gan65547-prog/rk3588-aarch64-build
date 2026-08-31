#include <QApplication>
#include <QLabel>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QLabel label(QStringLiteral("Hello Qt on RK3568"));
    label.resize(640, 240);
    label.setAlignment(Qt::AlignCenter);
    label.show();
    return app.exec();
}
