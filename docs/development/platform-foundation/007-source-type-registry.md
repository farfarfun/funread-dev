# 采集源注册表(`sources/factory.py`)


改造前是 if/elif 硬编码两个类型;改造后:

```python
_REGISTRY: Dict[str, Tuple[Type[LocalSourceStore], str]] = {}

def register_source_type(source_type: str, processor_cls, cate1: str) -> None:
    _REGISTRY[source_type] = (processor_cls, cate1)

register_source_type("booksource", BookSourceProcessor, cate1="book")
register_source_type("rsssource", RSSSourceProcessor, cate1="rss")
```

以后接一个新的采集源站点/格式,只需要:

1. 写一个 `class XxxProcessor(SourceProcessor)`,实现 `loader()` 和 `source_format()`(参考 `sources/book.py` / `sources/rss.py`);
2. 在 `factory.py` 底部调一行 `register_source_type("xxxsource", XxxProcessor, cate1="xxx")`。

不需要改 `SourceStoreFactory.create()` 本身,也不需要改 `SourceBuildContext`/`GenerateSourceTask` —— 它们都是拿 `source_type` 字符串去查注册表。这是照抄 funflix `services/collect/registry.py` 的思路,但**没有**照抄它的"从 URL 自动探测 source_type"那部分(`detect_source()`),因为 funread 这边一直是调用方显式传 `source_type` 字符串,没有这个需求。
