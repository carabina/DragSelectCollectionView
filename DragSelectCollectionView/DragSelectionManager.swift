//
//  DragSelectionManager.swift
//  DragSelectionCollectionView
//
//  Created by Haskel Ash on 9/14/16.
//  Copyright © 2016 Haskel Ash. All rights reserved.
//

import UIKit

internal class DragSelectionManager: NSObject {
    private weak var collectionView: UICollectionView!
    private var selectedIndices = [IndexPath]()
    private let nilPath = IndexPath(item: -1, section: -1)

    ///Initializes a `DragSelectionManager` with the provided `UICollectionView`.
    internal init(collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    /**
     Sets a maximum number of cells that may be selected. `nil` by default.
     Setting this value to a value of zero or lower effectively disables selection.
     Setting this value to `nil` removes any upper limit to selection.
     If when setting a new value, the selection manager already has a greater number
     of cells selected, then the apporpriate number of the most recently selected cells
     will automatically be deselected.
     */
    private var maxSelectionCount: Int? {
        didSet {
            guard let max = maxSelectionCount else { return }
            var count = selectedIndices.count
            while count > max {
                let path = selectedIndices.removeLast()
                collectionView.deselectItem(at: path, animated: true)
                collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: path)
                count -= 1
            }
        }
    }

    /**
     Tells the selection manager to set the cell at `indexPath` to `selected`.

     If `collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and `selected` is `true`, this method does nothing.

     If `collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and `selected` is `false`, this method does nothing.
     - Parameter indexPath: the index path to select / deselect.
     - Parameter selected: `true` to select, `false` to deselect.
     - Returns: the new selected state of the cell at `indexPath`.
     `true` for selected, `false` for deselected.
     */
    @discardableResult internal func setSelected(_ selected: Bool, for indexPath: IndexPath) -> Bool {
        if (collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: indexPath) == false && selected)
        || (collectionView.delegate?.collectionView?(collectionView, shouldDeselectItemAt: indexPath) == false && !selected) {
            return selectedIndices.contains(indexPath) //return state of selection, don't do anything
        }

        if selected {
            if selectedIndices.contains(indexPath) {
                return true //already selected, don't do anything
            } else if maxSelectionCount == nil || selectedIndices.count < maxSelectionCount! {
                selectedIndices.append(indexPath)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
                return true //not already selected and doesn't exceed max, insert
            } else {
                return false //not already selected but exceeds max, don't insert
            }
        } else if let i = selectedIndices.index(of: indexPath) {
            selectedIndices.remove(at: i)
            collectionView.deselectItem(at: indexPath, animated: true)
            collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: indexPath)
            return false //selected, remove selection
        } else {
            return false //already not selected, do nothing
        }
    }

    /**
     Changes the selected state of the cell at `indexPath`.

     If `collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and the cell is currently deselected, this method does nothing.

     If `collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath)`
     return `false` for this `indexPath`, and the cell is currently selected, this method does nothing.
     - Parameter indexPath: the index path of the cell to toggle.
     - Returns: the new selected state of the cell at `indexPath`.
     `true` for selected, `false` for deselected.
     */
    @discardableResult internal func toggleSelected(indexPath: IndexPath) -> Bool {
        if let i = selectedIndices.index(of:indexPath) { //is selected, attempt remove selection
            if collectionView.delegate?.collectionView?(collectionView, shouldDeselectItemAt: indexPath) == true {
                selectedIndices.remove(at: i)
                collectionView.deselectItem(at: indexPath, animated: true)
                collectionView.delegate?.collectionView?(collectionView, didDeselectItemAt: indexPath)
                return false
            } else { return true } //deselection disallowed, keep selected
        } else { //is unselected, attempt selection
            if collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: indexPath) == true &&
            (maxSelectionCount == nil || selectedIndices.count < maxSelectionCount!) {
                selectedIndices.append(indexPath)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
                return true
            } else { return false } //selection disallowed, keep unselected
        }
    }

    /**
     Selectes all indices from `from` until `to`, inclusive.
     Deselects all indices from `min` up until the lower of `from` and `to`.
     Deselects all indice from `max` down until the greater of `from` and `to`.
     - Parameter from: the start of the selected range.
     - Parameter to: the end of the selected range.
     May be less than, equal to, or greater than `from`.
     - Parameter min: the smallest index from which to deselect up until,
     but not including, the start of the selected range.
     - Parameter max: the greates index from which to deselect down until,
     but not including, the end of the selected range.
     */
    internal func selectRange(from: IndexPath, to: IndexPath, min: IndexPath, max: IndexPath) {
        if from.compare(to) == .orderedAscending {
            //when selecting from first selection forwards
            iterate(start: from, end: to, block: { indexPath in
                self.setSelected(true, for: indexPath)
            })
            if max != nilPath && to.compare(max) == .orderedAscending {
                //deselect items after current selection
                iterate(start: to, end: max, openLeft: true, block: { indexPath in
                    self.setSelected(false, for: indexPath)
                })
            }
            if min != nilPath && min.compare(from) == .orderedAscending {
                //deselect items before first selection
                iterate(start: min, end: from, openRight: true, block: { indexPath in
                    self.setSelected(false, for: indexPath)
                })
            }
        } else if from.compare(to) == .orderedDescending {
            //when selecting from first selection backwards
            iterate(start: to, end: from, block: { indexPath in
                self.setSelected(true, for: indexPath)
            })
            if min != nilPath && min.compare(to) == .orderedAscending {
                //deselect items before current selection
                iterate(start: min, end: to, openRight: true, block: { indexPath in
                    self.setSelected(false, for: indexPath)
                })
            }
            if max != nilPath && from.compare(max) == .orderedAscending {
                //deselect items after first selection
                iterate(start: from, end: max, openLeft: true, block: { indexPath in
                    self.setSelected(false, for: indexPath)

                })
            }
        } else {
            //finger is back on first item, deselect everything
            iterate(start: min, end: max, block: { indexPath in
                if indexPath != from {
                    self.setSelected(false, for: indexPath)
                }
            })
            print(selectedIndices)
        }
    }

    private func iterate(start: IndexPath, end: IndexPath,
                         openLeft: Bool = false, openRight: Bool = false,
                         block:(_ indexPath: IndexPath)->()) {

        var current = start
        var last = end

        if openLeft {
            if current.item + 1 < collectionView.numberOfItems(inSection: current.section) {
                current = IndexPath(item: current.item+1, section: current.section)
            } else {
                for section in current.section+1..<collectionView.numberOfSections {
                    if collectionView.numberOfItems(inSection: section) > 0 {
                        current = IndexPath(item: 0, section: section)
                        break
                    }
                }
            }
        }

        if openRight {
            if last.item > 0 {
                last = IndexPath(item: last.item-1, section: last.section)
            } else {
                for section in stride(from: last.section-1, through: 0, by: -1) {
                    let items = collectionView.numberOfItems(inSection: section)
                    if items > 0 {
                        last = IndexPath(item: items-1, section: section)
                        break
                    }
                }
            }
        }

        while current.compare(last) != .orderedDescending {
            block(current)
            if collectionView.numberOfItems(inSection: current.section) > current.item + 1 {
                current = IndexPath(item: current.item+1, section: current.section)
            } else {
                current = IndexPath(item: 0, section: current.section+1)
            }
        }
    }

    internal func selectAll() {
        selectedIndices.removeAll()

        let sections = collectionView.numberOfSections
        for section in 0 ..< sections  {
            let items = collectionView.numberOfItems(inSection: section)
            for item in 0 ..< items {
                let path = IndexPath(item: item, section: section)
                if collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: path) == true {
                    selectedIndices.append(path)
                    collectionView?.selectItem(at: path, animated: true, scrollPosition: [])
                    collectionView?.delegate?.collectionView?(collectionView, didSelectItemAt: path)
                }
            }
        }
    }

    internal func clearSelected() {
        for i in stride(from: selectedIndices.count-1, through: 0, by: -1) {
            let path = selectedIndices[i]
            selectedIndices.remove(at: i)
            collectionView?.deselectItem(at: path, animated: true)
            collectionView?.delegate?.collectionView?(collectionView, didDeselectItemAt: path)
        }
    }

    internal func getSelectedCount() -> Int {
        return selectedIndices.count
    }

    internal func isIndexSelected(_ indexPath: IndexPath) -> Bool {
        return selectedIndices.contains(indexPath)
    }
}
