# { ... }:
# let
#     o.enableWebUI = true;
#     o.storagePath = "/home/elly/.cache/resilio-sync";
#     o.directoryRoot = "/home/elly/Sync";
# in
{
#     services.resilio = {
#         enable = true;
#         storagePath = o.storagePath;
#         enableWebUI = o.enableWebUI;
#         directoryRoot = o.directoryRoot;
        
#     };
}
