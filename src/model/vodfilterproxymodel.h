#ifndef VODFILTERPROXYMODEL_H
#define VODFILTERPROXYMODEL_H

#include <QSortFilterProxyModel>
#include <QString>
#include <QVariantMap>

class VodFilterProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(bool oldestFirst READ oldestFirst WRITE setOldestFirst NOTIFY oldestFirstChanged)

public:
    explicit VodFilterProxyModel(QObject *parent = nullptr);

    QString filterText() const;
    void setFilterText(const QString &filterText);

    bool oldestFirst() const;
    void setOldestFirst(bool oldestFirst);

    Q_INVOKABLE int count() const;
    Q_INVOKABLE QVariantMap itemAt(int row) const;

signals:
    void filterTextChanged();
    void oldestFirstChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    QString mFilterText;
    bool mOldestFirst = false;
};

#endif // VODFILTERPROXYMODEL_H
