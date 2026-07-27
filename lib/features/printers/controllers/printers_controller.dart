import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/printers/data/printers_repository.dart';
import 'package:ds_clickeat_web_admin/features/printers/models/printer.dart';

class PrintersState {
  final List<Printer> printers;
  final bool loading;
  final String? error;

  const PrintersState({
    this.printers = const [],
    this.loading = false,
    this.error,
  });

  PrintersState copyWith({
    List<Printer>? printers,
    bool? loading,
    String? error,
  }) => PrintersState(
    printers: printers ?? this.printers,
    loading: loading ?? this.loading,
    error: error,
  );
}

final printersControllerProvider =
    StateNotifierProvider<PrintersController, PrintersState>((ref) {
      return PrintersController(ref);
    });

class PrintersController extends StateNotifier<PrintersState> {
  PrintersController(this._ref) : super(const PrintersState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  PrintersRepository get _repo => _ref.read(printersRepositoryProvider);

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repo.getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort(
        (a, b) => a.prinName.toLowerCase().compareTo(b.prinName.toLowerCase()),
      );
      state = PrintersState(printers: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Runs [action] and reloads the list on success. Used for create/update:
  /// `prin_is_default` is unique per premise, so an update to one row can
  /// change another row's default flag server-side — a full reload keeps
  /// every row in sync instead of only patching the edited one.
  Future<String?> _mutate(int premId, Future<void> Function() action) async {
    try {
      await action();
      await load(premId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _mutateLocal(
    int premId,
    Future<void> Function() action,
    void Function() applyLocal,
  ) async {
    try {
      await action();
      if (premId == _activePremId) applyLocal();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> createPrinter(
    int premId, {
    required String name,
    required String connectionType,
    required String usageType,
    String? ip,
    int? port,
    String? windowsName,
    required int paperWidth,
    required bool autoCut,
    required bool beep,
    required bool isDefault,
    required bool isActive,
  }) => _mutate(
    premId,
    () => _repo.createPrinter(
      premId: premId,
      name: name,
      connectionType: connectionType,
      usageType: usageType,
      ip: ip,
      port: port,
      windowsName: windowsName,
      paperWidth: paperWidth,
      autoCut: autoCut,
      beep: beep,
      isDefault: isDefault,
      isActive: isActive,
    ),
  );

  Future<String?> updatePrinter(
    int premId,
    int prinId, {
    required String name,
    required String connectionType,
    required String usageType,
    String? ip,
    int? port,
    String? windowsName,
    required int paperWidth,
    required bool autoCut,
    required bool beep,
    required bool isDefault,
    required bool isActive,
  }) => _mutate(
    premId,
    () => _repo.updatePrinter(
      premId: premId,
      prinId: prinId,
      name: name,
      connectionType: connectionType,
      usageType: usageType,
      ip: ip,
      port: port,
      windowsName: windowsName,
      paperWidth: paperWidth,
      autoCut: autoCut,
      beep: beep,
      isDefault: isDefault,
      isActive: isActive,
    ),
  );

  Future<String?> deletePrinter(int premId, int prinId) => _mutateLocal(
    premId,
    () => _repo.deletePrinter(premId: premId, prinId: prinId),
    () => state = state.copyWith(
      printers: [
        for (final printer in state.printers)
          if (printer.prinId != prinId) printer,
      ],
    ),
  );

  /// Flips a printer's active flag, persisting the change via update.
  Future<String?> toggleActive(int premId, Printer printer) => _mutateLocal(
    premId,
    () => _repo.updatePrinter(
      premId: premId,
      prinId: printer.prinId,
      name: printer.prinName,
      connectionType: printer.prinConnectionType,
      usageType: printer.prinUsageType,
      ip: printer.prinIp,
      port: printer.prinPort,
      windowsName: printer.prinWindowsName,
      paperWidth: printer.prinPaperWidth,
      autoCut: printer.prinAutoCut,
      beep: printer.prinBeep,
      isDefault: printer.prinIsDefault,
      isActive: !printer.prinIsActive,
    ),
    () => _patchActive(printer.prinId, !printer.prinIsActive),
  );

  void _patchActive(int prinId, bool isActive) {
    state = state.copyWith(
      printers: [
        for (final printer in state.printers)
          if (printer.prinId == prinId)
            printer.copyWith(prinIsActive: isActive)
          else
            printer,
      ],
    );
  }
}
