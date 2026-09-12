import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../utils/json_utils.dart';
import 'state_views.dart';

/// Infinite-scroll list over a paginated endpoint.
///
/// Handles first load, empty and error states, pull-to-refresh and loading
/// the next page near the bottom. Change [reloadKey] (e.g. the search query)
/// to reset the list.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.all(16),
    this.reloadKey,
    this.spacing = 12,
    this.onLoaded,
    this.transform,
    this.columns = 1,
  });

  /// Loads page [page] (1-based).
  final Future<PageResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;

  /// Scrolls together with the list (search field, counters...).
  final Widget? header;

  /// Called after every page with all items loaded so far and the server total,
  /// so a header can show counters without fetching the list twice.
  final void Function(List<T> items, int total)? onLoaded;

  /// Reorders or filters the accumulated items just before they are rendered
  /// (client-side sorting, for endpoints that offer none).
  final List<T> Function(List<T> items)? transform;
  final EdgeInsetsGeometry padding;
  final Object? reloadKey;
  final double spacing;

  /// Items per row. More than one turns the list into a grid of equal-width
  /// cards, which is how the web lays cards out on a tablet.
  final int columns;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _reset();
  }

  Future<void> _reset() async {
    setState(() {
      _generation++;
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetchPage(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore && result.items.isNotEmpty;
      });
      widget.onLoaded?.call(List.unmodifiable(_items), result.total);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 400) _loadNext();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final Widget body;

    if (_items.isEmpty && _loading) {
      body = const Padding(padding: EdgeInsets.only(top: 80), child: LoadingView());
    } else if (_items.isEmpty && _error != null) {
      body = Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(message: _error!, onRetry: _loadNext),
      );
    } else if (_items.isEmpty) {
      body = Padding(padding: const EdgeInsets.only(top: 40), child: widget.empty);
    } else {
      final items = widget.transform?.call(List.unmodifiable(_items)) ?? _items;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.columns <= 1)
            for (final item in items) ...[
              widget.itemBuilder(context, item),
              SizedBox(height: widget.spacing),
            ]
          else
            for (var start = 0; start < items.length; start += widget.columns) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < widget.columns; column++) ...[
                      Expanded(
                        child: start + column < items.length
                            ? widget.itemBuilder(context, items[start + column])
                            : const SizedBox.shrink(),
                      ),
                      if (column < widget.columns - 1) SizedBox(width: widget.spacing),
                    ],
                  ],
                ),
              ),
              SizedBox(height: widget.spacing),
            ],
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_error != null && !_loading)
            TextButton(onPressed: _loadNext, child: const Text("Qayta yuklash")),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _reset,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          children: [
            if (header != null) header,
            body,
          ],
        ),
      ),
    );
  }
}
