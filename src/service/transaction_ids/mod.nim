const
  RustPath* = "service/transaction_ids/mod.rs"
  RustCrate* = "service"

import std/tables

type
  TransactionIdFetchResult* = tuple[ok: bool, data: string]

  TransactionIdStore* = object
    responses*: Table[string, string]

proc initTransactionIdStore*(): TransactionIdStore =
  TransactionIdStore(responses: initTable[string, string]())

proc txnKey*(userId, deviceId, txnId: string): string =
  userId & "\xff" & deviceId & "\xff" & txnId

proc addTxnid*(
  store: var TransactionIdStore;
  userId, deviceId, txnId: string;
  data: string;
) =
  store.responses[txnKey(userId, deviceId, txnId)] = data

proc addTxnid*(
  store: var TransactionIdStore;
  userId, txnId: string;
  data: string;
) =
  store.addTxnid(userId, "", txnId, data)

proc existingTxnid*(
  store: TransactionIdStore;
  userId, deviceId, txnId: string;
): TransactionIdFetchResult =
  let key = txnKey(userId, deviceId, txnId)
  if key notin store.responses:
    return (false, "")
  (true, store.responses[key])

proc existingTxnid*(
  store: TransactionIdStore;
  userId, txnId: string;
): TransactionIdFetchResult =
  store.existingTxnid(userId, "", txnId)
