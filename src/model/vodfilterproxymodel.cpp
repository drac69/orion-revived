#include "vodfilterproxymodel.h"

#include "vodlistmodel.h"

#include <QRegularExpression>
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

QVariantMap VodFilterProxyModel::itemAt(int row) const
{
    QVariantMap out;
    const QModelIndex itemIndex = index(row, 0);
    if (!itemIndex.isValid()) {
        return out;
    }

    const auto roles = roleNames();
    for (auto role = roles.constBegin(); role != roles.constEnd(); role++) {
        const QString name = QString::fromUtf8(role.value());
        const QVariant value = data(itemIndex, role.key());
        out.insert(name, value);
        if (name == QLatin1String("id")) {
            out.insert(QStringLiteral("_id"), value);
        }
    }

    return out;
}

bool VodFilterProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (mFilterText.isEmpty()) {
        return true;
    }

    const QModelIndex sourceIndex = sourceModel()->index(sourceRow, 0, sourceParent);
    const QString mutedSegments = sourceModel()->data(sourceIndex, VodListModel::MutedSegments).toString();
    const QString mutedSegmentRanges = sourceModel()->data(sourceIndex, VodListModel::MutedSegmentRanges).toString();
    const QString haystack = sourceModel()->data(sourceIndex, VodListModel::Title).toString()
            + "\n" + sourceModel()->data(sourceIndex, VodListModel::Game).toString()
            + "\n" + sourceModel()->data(sourceIndex, VodListModel::Type).toString()
            + "\n" + sourceModel()->data(sourceIndex, VodListModel::CreatedAt).toString()
            + "\n" + (mutedSegments.isEmpty() ? QString() : QStringLiteral("muted ") + mutedSegments)
            + "\n" + mutedSegmentRanges;
    const QStringList tokens = mFilterText.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);

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
