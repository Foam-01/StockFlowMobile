-- CreateEnum
CREATE TYPE "WorkOrderStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'SUBMITTED', 'NEEDS_REVISION', 'APPROVED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "WorkOrderPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "EvidenceCategory" AS ENUM ('BEFORE', 'AFTER', 'OTHER');

-- CreateEnum
CREATE TYPE "WorkOrderEventType" AS ENUM ('CREATED', 'ASSIGNED', 'STARTED', 'CHECKLIST_UPDATED', 'EVIDENCE_ADDED', 'EVIDENCE_REMOVED', 'SUBMITTED', 'CHANGES_REQUESTED', 'APPROVED', 'CANCELLED', 'MATERIAL_ISSUED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "Role" ADD VALUE 'TECHNICIAN';
ALTER TYPE "Role" ADD VALUE 'SUPERVISOR';

-- AlterTable
ALTER TABLE "StockTransaction" ADD COLUMN     "workOrderId" TEXT;

-- CreateTable
CREATE TABLE "ChecklistTemplate" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "ChecklistTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChecklistTemplateItem" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "required" BOOLEAN NOT NULL DEFAULT true,
    "position" INTEGER NOT NULL,

    CONSTRAINT "ChecklistTemplateItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkOrder" (
    "id" TEXT NOT NULL,
    "number" SERIAL NOT NULL,
    "clientUuid" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "siteName" TEXT NOT NULL,
    "siteAddress" TEXT,
    "priority" "WorkOrderPriority" NOT NULL DEFAULT 'NORMAL',
    "status" "WorkOrderStatus" NOT NULL DEFAULT 'OPEN',
    "dueAt" TIMESTAMP(3),
    "requiredEvidence" "EvidenceCategory"[],
    "templateId" TEXT,
    "createdById" TEXT NOT NULL,
    "assigneeId" TEXT,
    "reviewerId" TEXT,
    "reviewedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "startedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "reviewNote" TEXT,
    "cancelReason" TEXT,

    CONSTRAINT "WorkOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkOrderChecklistItem" (
    "id" TEXT NOT NULL,
    "workOrderId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "required" BOOLEAN NOT NULL DEFAULT true,
    "position" INTEGER NOT NULL,
    "done" BOOLEAN NOT NULL DEFAULT false,
    "note" TEXT,
    "completedById" TEXT,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "WorkOrderChecklistItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkOrderMaterial" (
    "id" TEXT NOT NULL,
    "workOrderId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "plannedQty" INTEGER NOT NULL,

    CONSTRAINT "WorkOrderMaterial_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkOrderEvidence" (
    "id" TEXT NOT NULL,
    "workOrderId" TEXT NOT NULL,
    "category" "EvidenceCategory" NOT NULL,
    "url" TEXT NOT NULL,
    "publicId" TEXT NOT NULL,
    "note" TEXT,
    "uploadedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WorkOrderEvidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkOrderEvent" (
    "id" TEXT NOT NULL,
    "workOrderId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "type" "WorkOrderEventType" NOT NULL,
    "fromStatus" "WorkOrderStatus",
    "toStatus" "WorkOrderStatus",
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WorkOrderEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ChecklistTemplate_name_key" ON "ChecklistTemplate"("name");

-- CreateIndex
CREATE UNIQUE INDEX "ChecklistTemplateItem_templateId_position_key" ON "ChecklistTemplateItem"("templateId", "position");

-- CreateIndex
CREATE UNIQUE INDEX "WorkOrder_number_key" ON "WorkOrder"("number");

-- CreateIndex
CREATE UNIQUE INDEX "WorkOrder_clientUuid_key" ON "WorkOrder"("clientUuid");

-- CreateIndex
CREATE INDEX "WorkOrder_status_idx" ON "WorkOrder"("status");

-- CreateIndex
CREATE INDEX "WorkOrder_assigneeId_status_idx" ON "WorkOrder"("assigneeId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "WorkOrderChecklistItem_workOrderId_position_key" ON "WorkOrderChecklistItem"("workOrderId", "position");

-- CreateIndex
CREATE UNIQUE INDEX "WorkOrderMaterial_workOrderId_productId_key" ON "WorkOrderMaterial"("workOrderId", "productId");

-- CreateIndex
CREATE UNIQUE INDEX "WorkOrderEvidence_publicId_key" ON "WorkOrderEvidence"("publicId");

-- CreateIndex
CREATE INDEX "WorkOrderEvidence_workOrderId_idx" ON "WorkOrderEvidence"("workOrderId");

-- CreateIndex
CREATE INDEX "WorkOrderEvent_workOrderId_createdAt_idx" ON "WorkOrderEvent"("workOrderId", "createdAt");

-- CreateIndex
CREATE INDEX "StockTransaction_workOrderId_idx" ON "StockTransaction"("workOrderId");

-- AddForeignKey
ALTER TABLE "StockTransaction" ADD CONSTRAINT "StockTransaction_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "WorkOrder"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChecklistTemplateItem" ADD CONSTRAINT "ChecklistTemplateItem_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "ChecklistTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrder" ADD CONSTRAINT "WorkOrder_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "ChecklistTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrder" ADD CONSTRAINT "WorkOrder_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrder" ADD CONSTRAINT "WorkOrder_assigneeId_fkey" FOREIGN KEY ("assigneeId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrder" ADD CONSTRAINT "WorkOrder_reviewerId_fkey" FOREIGN KEY ("reviewerId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrder" ADD CONSTRAINT "WorkOrder_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderChecklistItem" ADD CONSTRAINT "WorkOrderChecklistItem_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "WorkOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderChecklistItem" ADD CONSTRAINT "WorkOrderChecklistItem_completedById_fkey" FOREIGN KEY ("completedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderMaterial" ADD CONSTRAINT "WorkOrderMaterial_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "WorkOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderMaterial" ADD CONSTRAINT "WorkOrderMaterial_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderEvidence" ADD CONSTRAINT "WorkOrderEvidence_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "WorkOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderEvidence" ADD CONSTRAINT "WorkOrderEvidence_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderEvent" ADD CONSTRAINT "WorkOrderEvent_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "WorkOrder"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkOrderEvent" ADD CONSTRAINT "WorkOrderEvent_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

