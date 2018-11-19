//
//  GeneratorSource.swift
//  DeltaFox
//
//  Created by Karsten Bruns on 27.08.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

@objc private protocol TableViewDelegate: NSObjectProtocol {
    @objc optional func tableView(_ tableView: UITableView, willDisplayCell cell: Any!, forRowAt indexPath: IndexPath)
    @objc optional func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> Any!
    @objc optional func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> Any!
    @objc optional func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath)
    @objc optional func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?
    @objc optional func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    @objc optional func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> Any!
    @objc optional func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> Any!
    @objc optional func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> Any!
    @objc optional func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool
    @objc optional func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath)
    @objc optional func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?)
    @objc optional func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
    @objc optional func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
}


@objc private protocol TableViewDataSource: NSObjectProtocol {
    @objc func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    @objc func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> Any!
    @objc optional func numberOfSections(in tableView: UITableView) -> Int
    @objc optional func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    @objc optional func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    @objc optional func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    @objc optional func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool
    @objc optional func sectionIndexTitles(for tableView: UITableView) -> [String]?
    @objc optional func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int
    @objc optional func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: Any!, forRowAt indexPath: IndexPath)
    @objc optional func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
}


@objc private protocol TableViewDataSourcePrefetching : NSObjectProtocol {
    @objc func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath])
    @objc optional func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath])
}


@objc private protocol TableViewDragDelegate: NSObjectProtocol {
    @objc optional func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters?
}


@objc private protocol TableViewDropDelegate: NSObjectProtocol {
    @objc func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator)
    @objc optional func tableView(_ tableView: UITableView, dropPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters?
}
