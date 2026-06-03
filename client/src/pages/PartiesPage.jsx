import { useEffect, useMemo, useState } from "react";
import PartyCard from "../components/party/PartyCard";
import PartyFormModal from "../components/party/PartyFormModal";
import PartyLedgerModal from "../components/party/PartyLedgerModal";
import {
  createParty,
  deleteParty,
  getParties,
  getPartyLedger,
  getPartyStats,
  updateParty,
} from "../services/partyService";

export default function PartiesPage() {
  const [parties, setParties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitLoading, setSubmitLoading] = useState(false);
  const [ledgerLoading, setLedgerLoading] = useState(false);

  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [ledgerOpen, setLedgerOpen] = useState(false);
  const [editData, setEditData] = useState(null);
  const [ledgerData, setLedgerData] = useState(null);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const [stats, setStats] = useState(null);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 12,
    total: 0,
    totalPages: 1,
  });

  const fetchParties = async ({
    page = 1,
    limit = pagination.limit,
    searchText = search,
  } = {}) => {
    try {
      setLoading(true);
      setError("");

      const [partyRes, statsRes] = await Promise.all([
        getParties({
          page,
          limit,
          search: searchText,
        }),
        getPartyStats(),
      ]);

      setParties(partyRes?.items || []);
      setPagination(
        partyRes?.pagination || {
          page: 1,
          limit: 12,
          total: 0,
          totalPages: 1,
        }
      );
      setStats(statsRes || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load parties");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchParties({ page: 1 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filteredParties = useMemo(() => {
    const q = search.toLowerCase().trim();
    if (!q) return parties;

    return parties.filter((party) =>
      [
        party.name,
        party.phone,
        party.email,
        party.address,
        party.type,
        party.contactPerson,
        
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(q)
    );
  }, [parties, search]);

  const handleCreateClick = () => {
    setEditData(null);
    setModalOpen(true);
  };

  const handleEdit = (party) => {
    setEditData(party);
    setModalOpen(true);
  };

  const handleSubmit = async (formData) => {
    try {
      setSubmitLoading(true);
      setError("");
      setSuccess("");

      if (editData?._id) {
        await updateParty(editData._id, formData);
        setSuccess("Party updated successfully");
      } else {
        await createParty(formData);
        setSuccess("Party created successfully");
      }

      setModalOpen(false);
      setEditData(null);
      await fetchParties({ page: pagination.page });
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to save party");
    } finally {
      setSubmitLoading(false);
    }
  };

  const handleDelete = async (party) => {
    const ok = window.confirm(
      `Delete "${party.name}"? It will move to recycle bin.`
    );
    if (!ok) return;

    try {
      setError("");
      setSuccess("");

      await deleteParty(party._id);
      setSuccess("Party moved to recycle bin");

      const nextPage =
        parties.length === 1 && pagination.page > 1
          ? pagination.page - 1
          : pagination.page;

      await fetchParties({ page: nextPage });
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to delete party");
    }
  };

  const handleViewLedger = async (party) => {
    try {
      setLedgerOpen(true);
      setLedgerLoading(true);
      setLedgerData(null);
      setError("");

      const data = await getPartyLedger(party._id);
      setLedgerData(data);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load ledger");
      setLedgerOpen(false);
    } finally {
      setLedgerLoading(false);
    }
  };

  const handleSearchSubmit = async (e) => {
    e.preventDefault();
    await fetchParties({ page: 1, searchText: search });
  };

  const handleClearSearch = async () => {
    setSearch("");
    await fetchParties({ page: 1, searchText: "" });
  };

  const goToPage = async (page) => {
    if (page < 1 || page > pagination.totalPages) return;
    await fetchParties({ page });
  };

  return (
    <div className="min-h-screen bg-slate-950 px-4 py-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 rounded-3xl border border-emerald-500/20 bg-slate-900 p-5 sm:p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <h1 className="text-2xl font-bold text-emerald-200 sm:text-3xl">
                Party Management
              </h1>
              <p className="mt-1 text-sm text-emerald-200/70">
                Manage customers, suppliers, and their ledger information.
              </p>
            </div>

            <button
              onClick={handleCreateClick}
              className="rounded-2xl bg-emerald-500 px-5 py-3 text-sm font-semibold text-slate-950 shadow hover:opacity-90"
            >
              + Add Party
            </button>
          </div>

          <form onSubmit={handleSearchSubmit} className="mt-5 flex gap-3">
            <input
              type="text"
              placeholder="Search by name, phone, email, address or type..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-2xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200 outline-none placeholder:text-emerald-200/60 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
            />
            <button
              type="submit"
              className="rounded-2xl border border-emerald-500/30 bg-emerald-500/15 px-4 py-3 text-sm font-medium text-emerald-200"
            >
              Search
            </button>
            <button
              type="button"
              onClick={handleClearSearch}
              className="rounded-2xl border border-slate-700 bg-slate-800 px-4 py-3 text-sm font-medium text-slate-200"
            >
              Clear
            </button>
          </form>

          {error && (
            <div className="mt-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-300">
              {error}
            </div>
          )}

          {success && (
            <div className="mt-4 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
              {success}
            </div>
          )}
        </div>

        {stats && (
          <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-5">
              <p className="text-sm text-emerald-200/70">Total Parties</p>
              <h3 className="mt-2 text-2xl font-bold text-emerald-200">
                {stats.total}
              </h3>
            </div>

            <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-5">
              <p className="text-sm text-emerald-200/70">Customers</p>
              <h3 className="mt-2 text-2xl font-bold text-emerald-200">
                {stats.customers}
              </h3>
            </div>

            <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-5">
              <p className="text-sm text-emerald-200/70">Suppliers</p>
              <h3 className="mt-2 text-2xl font-bold text-emerald-200">
                {stats.suppliers}
              </h3>
            </div>

            <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-5">
              <p className="text-sm text-emerald-200/70">Opening Balance</p>
              <h3 className="mt-2 text-2xl font-bold text-emerald-200">
                Rs. {Number(stats.totalOpeningBalance || 0).toLocaleString()}
              </h3>
            </div>
          </div>
        )}

        {loading ? (
          <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-10 text-center text-emerald-200">
            Loading parties...
          </div>
        ) : filteredParties.length === 0 ? (
          <div className="rounded-3xl border border-emerald-500/20 bg-slate-900 p-10 text-center text-emerald-200">
            No parties found.
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {filteredParties.map((party) => (
                <PartyCard
                  key={party._id}
                  party={party}
                  onEdit={handleEdit}
                  onDelete={handleDelete}
                  onViewLedger={handleViewLedger}
                />
              ))}
            </div>

            <div className="mt-6 flex flex-col items-center justify-between gap-4 rounded-3xl border border-emerald-500/20 bg-slate-900 p-4 sm:flex-row">
              <div className="text-sm text-emerald-200/70">
                Page {pagination.page} of {pagination.totalPages} • Total{" "}
                {pagination.total} parties
              </div>

              <div className="flex gap-2">
                <button
                  onClick={() => goToPage(pagination.page - 1)}
                  disabled={pagination.page <= 1}
                  className="rounded-2xl border border-slate-700 px-4 py-2 text-sm text-slate-200 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Previous
                </button>

                <button
                  onClick={() => goToPage(pagination.page + 1)}
                  disabled={pagination.page >= pagination.totalPages}
                  className="rounded-2xl border border-slate-700 px-4 py-2 text-sm text-slate-200 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          </>
        )}
      </div>

      <PartyFormModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setEditData(null);
        }}
        onSubmit={handleSubmit}
        loading={submitLoading}
        editData={editData}
      />

      <PartyLedgerModal
        open={ledgerOpen}
        onClose={() => {
          setLedgerOpen(false);
          setLedgerData(null);
        }}
        ledger={ledgerData}
        loading={ledgerLoading}
      />
    </div>
  );
}