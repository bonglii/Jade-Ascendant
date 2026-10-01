extends Node

signal write_task_completed(result: Dictionary)
signal get_task_completed(result: Dictionary)
signal update_task_completed(result: Dictionary)
signal delete_task_completed(result: Dictionary)
signal document_changed(document_path: String, data: Dictionary)
signal query_task_completed(result: Dictionary)
signal collection_changed(collection_path: String, documents: Array)
signal batch_task_completed(result: Dictionary)
signal transaction_task_completed(result: Dictionary)

var _plugin_singleton: Object

func _connect_signals():
	if not _plugin_singleton:
		return
	_plugin_singleton.connect("firestore_write_task_completed", write_task_completed.emit)
	_plugin_singleton.connect("firestore_get_task_completed", get_task_completed.emit)
	_plugin_singleton.connect("firestore_update_task_completed", update_task_completed.emit)
	_plugin_singleton.connect("firestore_delete_task_completed", delete_task_completed.emit)
	_plugin_singleton.connect("firestore_document_changed", document_changed.emit)
	_plugin_singleton.connect("firestore_query_task_completed", query_task_completed.emit)
	_plugin_singleton.connect("firestore_collection_changed", collection_changed.emit)
	_plugin_singleton.connect("firestore_batch_task_completed", batch_task_completed.emit)
	_plugin_singleton.connect("firestore_transaction_task_completed", transaction_task_completed.emit)

func add_document(collection: String, data: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreAddDocument(collection, data)

func set_document(collection: String, documentId: String, data: Dictionary, merge: bool = false) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreSetDocument(collection, documentId, data, merge)

func get_document(collection: String, documentId: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreGetDocument(collection, documentId)

func get_documents_in_collection(collection: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreGetDocumentsInCollection(collection)

func update_document(collection: String, documentId: String, data: Dictionary) -> void:
		if _plugin_singleton:
			_plugin_singleton.firestoreUpdateDocument(collection, documentId, data)

func delete_document(collection: String, documentId: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreDeleteDocument(collection, documentId)

func listen_to_document(documentPath: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreListenToDocument(documentPath)

func query_documents(collection: String, filters: Array = [], order_by: String = "", order_descending: bool = false, limit_count: int = 0) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreQueryDocuments(collection, filters, order_by, order_descending, limit_count)

func stop_listening_to_document(documentPath: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreStopListeningToDocument(documentPath)

func use_emulator(host: String, port: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreUseEmulator(host, port)

func listen_to_collection(collection: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreListenToCollection(collection)

func stop_listening_to_collection(collection: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreStopListeningToCollection(collection)

func create_batch() -> int:
	if _plugin_singleton:
		return _plugin_singleton.firestoreCreateBatch()
	return -1

func batch_set(batch_id: int, collection: String, document_id: String, data: Dictionary, merge: bool = false) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreBatchSet(batch_id, collection, document_id, data, merge)

func batch_update(batch_id: int, collection: String, document_id: String, data: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreBatchUpdate(batch_id, collection, document_id, data)

func batch_delete(batch_id: int, collection: String, document_id: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreBatchDelete(batch_id, collection, document_id)

func commit_batch(batch_id: int) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreCommitBatch(batch_id)

func run_transaction(collection: String, document_id: String, update_data: Dictionary) -> void:
	if _plugin_singleton:
		_plugin_singleton.firestoreRunTransaction(collection, document_id, update_data)

func server_timestamp() -> Dictionary:
	if _plugin_singleton:
		return _plugin_singleton.firestoreServerTimestamp()
	return {}

func array_union(elements: Array) -> Dictionary:
	if _plugin_singleton:
		return _plugin_singleton.firestoreArrayUnion(elements)
	return {}

func array_remove(elements: Array) -> Dictionary:
	if _plugin_singleton:
		return _plugin_singleton.firestoreArrayRemove(elements)
	return {}

func increment_by(value: float) -> Dictionary:
	if _plugin_singleton:
		return _plugin_singleton.firestoreIncrementBy(value)
	return {}

func delete_field() -> Dictionary:
	if _plugin_singleton:
		return _plugin_singleton.firestoreDeleteField()
	return {}
