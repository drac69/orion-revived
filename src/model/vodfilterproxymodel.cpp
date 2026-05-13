#include "vodfilterproxymodel.h"

#include "vodlistmodel.h"

#include <QRegExp>
#include <QStringList>

VodFilterProxyModel::VodFilterProxyModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    sort(0, Qt::DescendingOrder);
}

QString VodFilterProxyModel::filterText() const
{
    return mFilterText;
}

void VodFilterProxyModel::setFilterText(const QString &filterText)
{
    const QString normalizedFilter = filterText.trimmed();
    if (mFilterText == normalizedFilter) {
        return;
    }

    mFilterText = normalizedFilter;
    invalidateFilter();
    emit filterTextChanged();
}

bool VodFilterProxyModel::oldestFirst() const
{
    return mOldestFirst;
}

void VodFilterProxyModel::setOldestFirst(bool oldestFirst)
{
    if (mOldestFirst == oldestFirst) {
        return;
    }

    mOldestFirst = oldestFirst;
    sort(0, mOldestFirst ? Qt::AscendingOrder : Qt::DescendingOrder);
    emit oldestFirstChanged();
}

int VodFilterProxyModel::count() const
{
    return rowCount();
}

bool VodFilterProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (mFilterText.isEmpty()) {
        return true;
    }

    const QModelIndex sourceIndex = sourceModel()->index(sourceRow, 0, sourceParent);
    const QString haystack = sourceModel()->data(sourceIndex, VodListModel::Title).toString()
            + "\n" + sourceModel()->data(sourceIndex, VodListModel::Game).toString()
            + "\n" + sourceModel()->data(sourceIndex, VodListModel::CreatedAt).toString();
    const QStringList tokens = mFilterText.split(QRegExp("\\s+"), QString::SkipEmptyParts);

    for (const QString &token : tokens) {
        if (!haystack.contains(token, Qt::CaseInsensitive)) {
            return false;
        }
    }

    return true;
}

bool VodFilterProxyModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    const QString leftCreatedAt = sourceModel()->data(left, VodListModel::CreatedAt).toString();
    const QString rightCreatedAt = sourceModel()->data(right, VodListModel::CreatedAt).toString();

    if (leftCreatedAt != rightCreatedAt) {
        return leftCreatedAt < rightCreatedAt;
    }

    return left.row() < right.row();
}
