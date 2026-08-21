from rest_framework.pagination import PageNumberPagination


class LargePageNumberPagination(PageNumberPagination):
    """
    Same page size (50) as the global default until the client explicitly
    asks for more via `?page_size=` — both frontends need this for lists
    they load in full rather than paginate through (e.g. Inventory products,
    which Flutter already requests with page_size=500; the base
    PageNumberPagination silently ignores that param since
    page_size_query_param is unset by default, so results were capped at 50
    regardless of what the client asked for).
    """

    page_size_query_param = "page_size"
    max_page_size = 1000
