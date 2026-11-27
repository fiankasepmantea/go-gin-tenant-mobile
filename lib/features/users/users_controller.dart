import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'user.dart';
import 'users_repository.dart';

/// What the user list shows. One immutable value; the controller replaces it.
class UsersState {
  const UsersState({
    this.items = const <User>[],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
    this.filters = const UsersFilters(),
  });

  final List<User> items;
  final int total;

  /// The last page that was loaded (0 before the first answer).
  final int page;
  final bool hasMore;

  /// The first page is loading and there is nothing to show yet.
  final bool loading;
  final bool loadingMore;

  /// The first page failed.
  final Object? error;

  /// A later page failed; the list stays and the footer offers a retry.
  final Object? loadMoreError;
  final UsersFilters filters;

  UsersState copyWith({
    List<User>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    UsersFilters? filters,
  }) {
    return UsersState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      filters: filters ?? this.filters,
    );
  }
}

/// The paged, filterable user list. Starts over when somebody signs in or out.
class UsersController extends Notifier<UsersState> {
  /// Every load takes a number; an answer that is no longer the latest is dropped, so a slow answer for old
  /// filters never overwrites a newer list.
  int _generation = 0;
  bool _alive = true;

  UsersRepository get _repository => ref.read(usersRepositoryProvider);

  @override
  UsersState build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _generation++;
    });
    final signedIn = ref.watch(signedInProvider);
    if (!signedIn) return const UsersState();
    unawaited(Future<void>.microtask(refresh));
    return const UsersState(loading: true);
  }

  /// Loads the first page again. [silent] keeps the current list on screen (pull to refresh, after a change).
  Future<void> refresh({bool silent = false}) async {
    if (!_alive) return;
    final generation = ++_generation;
    if (!silent) {
      state = state.copyWith(
        items: const <User>[],
        total: 0,
        page: 0,
        hasMore: false,
        loading: true,
        loadingMore: false,
        clearError: true,
        clearLoadMoreError: true,
      );
    }
    try {
      final result = await _repository.list(state.filters);
      if (!_alive || generation != _generation) return;
      state = state.copyWith(
        items: result.items,
        total: result.totalData,
        page: result.currentPage,
        hasMore: result.hasMore,
        loading: false,
        loadingMore: false,
        clearError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_alive || generation != _generation) return;
      if (silent && state.items.isNotEmpty) {
        // A failed background refresh keeps what is on screen.
        state = state.copyWith(loading: false);
      } else {
        state = state.copyWith(loading: false, error: error);
      }
    }
  }

  /// Appends the next page. Does nothing while a load is running or when there is no next page.
  Future<void> loadMore() async {
    if (!_alive) return;
    if (!state.hasMore || state.loading || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final result = await _repository.list(state.filters, page: state.page + 1);
      if (!_alive || generation != _generation) return;
      final known = <String>{for (final user in state.items) user.id};
      state = state.copyWith(
        items: <User>[
          ...state.items,
          for (final user in result.items)
            if (!known.contains(user.id)) user,
        ],
        total: result.totalData,
        page: result.currentPage,
        hasMore: result.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      if (!_alive || generation != _generation) return;
      state = state.copyWith(loadingMore: false, loadMoreError: error);
    }
  }

  Future<void> setFilters(UsersFilters filters) {
    state = state.copyWith(filters: filters);
    return refresh();
  }

  /// Activates or deactivates a user. Throws the API error so the screen can show it.
  Future<void> setActive(User user, {required bool active}) async {
    await _repository.setActive(user.id, active: active);
    if (!_alive) return;
    state = state.copyWith(
      items: <User>[
        for (final item in state.items)
          if (item.id == user.id)
            User(
              id: item.id,
              username: item.username,
              email: item.email,
              name: item.name,
              groupId: item.groupId,
              isActive: active,
              level: item.level,
            )
          else
            item,
      ],
    );
    // A filter on the status may no longer match the row; the server decides.
    if (state.filters.isActive != null) unawaited(refresh(silent: true));
  }

  /// Deletes a user. Throws the API error so the screen can show it.
  Future<void> remove(User user) async {
    await _repository.delete(user.id);
    if (!_alive) return;
    state = state.copyWith(
      items: <User>[
        for (final item in state.items)
          if (item.id != user.id) item,
      ],
      total: state.total > 0 ? state.total - 1 : 0,
    );
  }
}

final NotifierProvider<UsersController, UsersState> usersControllerProvider =
    NotifierProvider<UsersController, UsersState>(UsersController.new);
